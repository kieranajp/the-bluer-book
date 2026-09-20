package repository

// Proof that PostgreSQL, not the query text, is what keeps one home out of
// another's data. Every assertion below runs through the ordinary repositories
// against a real database, on a connection the isolation policies bind.
//
// The suite is worthless on a privileged connection: a superuser and a role
// holding BYPASSRLS both ignore every policy, and the table owner ignores any
// policy that is not FORCE'd. So it does not merely prefer the restricted role,
// it fails outright on any other. scripts/rls-test.sh builds both roles and
// points each suite at the one it needs.

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"testing"

	"github.com/google/uuid"
	"github.com/lib/pq"

	"github.com/kieranajp/the-bluer-book/internal/domain/pantry"
	"github.com/kieranajp/the-bluer-book/internal/domain/recipe"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/auth"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
)

// tenantTables are the nine tables under FORCE ROW LEVEL SECURITY. Everything
// else in the schema is either shared vocabulary or the identity tables that
// decide which home a request acts on.
var tenantTables = []string{
	"recipes", "steps", "recipe_ingredient", "recipe_label", "photos",
	"meal_plan_recipes", "ingredients", "pantry_items", "shopping_list_items",
}

// unpolicedHomeTables carry a home_id and stay outside the policies on purpose.
// They answer the question of which home a request acts on, so they are read
// before an answer exists.
var unpolicedHomeTables = []string{"home_members", "invitations"}

// requireEveryHomeTableAccountedFor fails on a table that carries a home_id and
// appears in neither list. A new one would inherit this role's default DML
// privileges with nothing scoping it, and read every home.
func requireEveryHomeTableAccountedFor(t *testing.T, sqlDB *sql.DB) {
	t.Helper()

	known := map[string]bool{}
	for _, table := range append(append([]string{}, tenantTables...), unpolicedHomeTables...) {
		known[table] = true
	}

	rows, err := sqlDB.Query(`
		SELECT c.table_name
		FROM information_schema.columns c
		INNER JOIN information_schema.tables t
			ON t.table_schema = c.table_schema AND t.table_name = c.table_name
		WHERE c.table_schema = 'public' AND c.column_name = 'home_id' AND t.table_type = 'BASE TABLE'`)
	if err != nil {
		t.Fatalf("list the tables carrying a home_id: %v", err)
	}
	defer rows.Close()

	for rows.Next() {
		var table string
		if err := rows.Scan(&table); err != nil {
			t.Fatalf("scan table name: %v", err)
		}
		if !known[table] {
			t.Errorf("%s carries a home_id but this suite does not know about it: put it under the isolation "+
				"policy and in tenantTables, or say why it belongs in unpolicedHomeTables", table)
		}
		delete(known, table)
	}
	if err := rows.Err(); err != nil {
		t.Fatalf("list the tables carrying a home_id: %v", err)
	}

	for table := range known {
		t.Errorf("%s is listed here but carries no home_id", table)
	}
}

// bypassesRLS reports whether the connected role escapes row-level security
// outright, and names it either way.
func bypassesRLS(t *testing.T, sqlDB *sql.DB) (role string, bypasses bool) {
	t.Helper()

	var super, bypass bool
	err := sqlDB.QueryRow(
		`SELECT rolname, rolsuper, rolbypassrls FROM pg_roles WHERE rolname = current_user`,
	).Scan(&role, &super, &bypass)
	if err != nil {
		t.Fatalf("read the connected role's privileges: %v", err)
	}
	return role, super || bypass
}

// rlsBinds reports whether the isolation policies apply to this connection at
// all, so a suite that needs the other kind of connection can say so plainly
// instead of failing on an empty read.
func rlsBinds(t *testing.T, sqlDB *sql.DB) (role string, bound bool) {
	t.Helper()

	role, bypasses := bypassesRLS(t, sqlDB)
	if bypasses {
		return role, false
	}

	var forced, owned bool
	err := sqlDB.QueryRow(
		`SELECT relrowsecurity AND relforcerowsecurity, pg_get_userbyid(relowner) = current_user
		 FROM pg_class WHERE oid = to_regclass('public.recipes')`,
	).Scan(&forced, &owned)
	if err != nil {
		t.Fatalf("read row security settings for recipes: %v", err)
	}
	return role, forced || !owned
}

// requireRestrictedRole is the reason to believe anything this file asserts.
// It fails — never skips — when the connection could satisfy the assertions
// below without a single policy being consulted. The previous attempt at this
// suite tested as a superuser and reported a clean run against policies that
// were never applied to it.
func requireRestrictedRole(t *testing.T, sqlDB *sql.DB) {
	t.Helper()

	role, bypasses := bypassesRLS(t, sqlDB)
	if bypasses {
		t.Fatalf("connected as %q, which holds SUPERUSER or BYPASSRLS: every assertion in this suite would pass "+
			"without a policy being applied. Point BLUER_BOOK_TEST_DSN at the application role instead.", role)
	}

	for _, table := range tenantTables {
		var owner string
		if err := sqlDB.QueryRow(
			`SELECT tableowner FROM pg_tables WHERE schemaname = 'public' AND tablename = $1`, table,
		).Scan(&owner); err != nil {
			t.Fatalf("read the owner of %s: %v", table, err)
		}
		if owner == role {
			t.Fatalf("connected as %q, which owns %s: an owner is bound only while FORCE is set and can drop it at will. "+
				"Point BLUER_BOOK_TEST_DSN at the application role instead.", role, table)
		}

		var enabled, forced bool
		if err := sqlDB.QueryRow(
			`SELECT relrowsecurity, relforcerowsecurity FROM pg_class WHERE oid = to_regclass('public.' || $1)`, table,
		).Scan(&enabled, &forced); err != nil {
			t.Fatalf("read row security settings for %s: %v", table, err)
		}
		if !enabled || !forced {
			t.Fatalf("%s reports ENABLE=%t FORCE=%t: migration 00014 has not been applied here", table, enabled, forced)
		}

		var policies int
		if err := sqlDB.QueryRow(
			`SELECT count(*) FROM pg_policies WHERE schemaname = 'public' AND tablename = $1 AND policyname = 'home_isolation'`,
			table,
		).Scan(&policies); err != nil {
			t.Fatalf("count policies on %s: %v", table, err)
		}
		if policies != 1 {
			t.Fatalf("%s carries %d home_isolation policies, want 1", table, policies)
		}
	}
}

// countInHome runs a scalar query inside a transaction that has published a
// home, which is the only way a restricted connection can see anything.
func countInHome(t *testing.T, sqlDB *sql.DB, home uuid.UUID, query string, args ...any) int {
	t.Helper()

	var n int
	err := inTestHome(sqlDB, home, func(tx *sql.Tx) error {
		return tx.QueryRow(query, args...).Scan(&n)
	})
	if err != nil {
		t.Fatalf("count in home %s: %v", home, err)
	}
	return n
}

func TestIsolation(t *testing.T) {
	sqlDB := openTestDB(t)
	requireRestrictedRole(t, sqlDB)
	requireEveryHomeTableAccountedFor(t, sqlDB)

	log := logger.New(logger.LogLevelError)
	recipes := NewRecipeRepository(sqlDB, log)
	pantryRepo := NewPantryRepository(sqlDB, log)
	dropTestVocabulary(t, sqlDB)

	homeA := makeHome(t, sqlDB, "isolation A")
	homeB := makeHome(t, sqlDB, "isolation B")
	ctxA := auth.WithHome(context.Background(), homeA)
	ctxB := auth.WithHome(context.Background(), homeB)

	t.Run("one home reads none of another's rows", func(t *testing.T) {
		const item = "isolation sentinel item"

		saved, err := recipes.SaveRecipe(ctxA, testRecipe("Isolation Sentinel", "isolation sentinel ingredient"))
		if err != nil {
			t.Fatalf("save as A: %v", err)
		}
		if err := recipes.AddToMealPlan(ctxA, saved.UUID); err != nil {
			t.Fatalf("add to A's meal plan: %v", err)
		}
		if err := pantryRepo.AddToPantry(ctxA, "isolation sentinel ingredient"); err != nil {
			t.Fatalf("stock A's pantry: %v", err)
		}
		if err := pantryRepo.AddCustomShoppingItem(ctxA, item); err != nil {
			t.Fatalf("add to A's shopping list: %v", err)
		}

		// A reads all four back first. Without that, a policy that denied
		// everybody everything would look exactly like isolation below.
		if _, err := recipes.GetRecipeByID(ctxA, saved.UUID); err != nil {
			t.Fatalf("A cannot read its own recipe, so nothing below means anything: %v", err)
		}
		if plan, err := recipes.ListMealPlanRecipes(ctxA); err != nil || len(plan) != 1 {
			t.Fatalf("A's meal plan holds %d recipes (err %v), want its own 1", len(plan), err)
		}
		if stock, err := pantryRepo.ListPantry(ctxA); err != nil || len(stock) != 1 {
			t.Fatalf("A's pantry holds %d items (err %v), want its own 1", len(stock), err)
		}
		if shopping, err := pantryRepo.ListCustomShoppingItems(ctxA); err != nil || len(shopping) != 1 {
			t.Fatalf("A's shopping list holds %d items (err %v), want its own 1", len(shopping), err)
		}

		if _, err := recipes.GetRecipeByID(ctxB, saved.UUID); !errors.Is(err, recipe.ErrRecipeNotFound) {
			t.Errorf("B fetching A's recipe by id returned %v, want a not-found error", err)
		}

		list, _, err := recipes.ListRecipes(ctxB, 100, 0, "", nil, "")
		if err != nil {
			t.Fatalf("list as B: %v", err)
		}
		for _, r := range list {
			if r.UUID == saved.UUID {
				t.Errorf("B's recipe list contained A's %s", saved.UUID)
			}
		}

		search, _, err := recipes.ListRecipes(ctxB, 100, 0, "Isolation Sentinel", nil, "")
		if err != nil {
			t.Fatalf("search as B: %v", err)
		}
		if len(search) != 0 {
			t.Errorf("B's search for A's recipe found %d", len(search))
		}

		plan, err := recipes.ListMealPlanRecipes(ctxB)
		if err != nil {
			t.Fatalf("list B's meal plan: %v", err)
		}
		for _, r := range plan {
			if r.UUID == saved.UUID {
				t.Errorf("B's meal plan contained A's recipe")
			}
		}

		stock, err := pantryRepo.ListPantry(ctxB)
		if err != nil {
			t.Fatalf("list B's pantry: %v", err)
		}
		if len(stock) != 0 {
			t.Errorf("B's pantry holds %v", stock)
		}

		shopping, err := pantryRepo.ListCustomShoppingItems(ctxB)
		if err != nil {
			t.Fatalf("list B's shopping list: %v", err)
		}
		for _, got := range shopping {
			if got == item {
				t.Errorf("B's shopping list contained A's %q", item)
			}
		}
	})

	t.Run("a write naming another home is refused", func(t *testing.T) {
		const stmt = `INSERT INTO recipes (uuid, name, home_id) VALUES ($1, $2, $3)`

		// The same statement naming A's own home, so the refusal below is the
		// policy rather than a missing grant or a broken column.
		if err := inTestHome(sqlDB, homeA, func(tx *sql.Tx) error {
			_, err := tx.Exec(stmt, uuid.New(), "Planted in A", homeA)
			return err
		}); err != nil {
			t.Fatalf("A cannot write into its own home: %v", err)
		}

		err := inTestHome(sqlDB, homeA, func(tx *sql.Tx) error {
			_, err := tx.Exec(stmt, uuid.New(), "Planted in B", homeB)
			return err
		})

		var pqErr *pq.Error
		if !errors.As(err, &pqErr) {
			t.Fatalf("insert into another home returned %v, want a row-level security violation", err)
		}
		if pqErr.Code != "42501" {
			t.Errorf("insert into another home raised SQLSTATE %s (%s), want 42501", pqErr.Code, pqErr.Message)
		}
	})

	t.Run("a write over another home's row changes nothing", func(t *testing.T) {
		saved, err := recipes.SaveRecipe(ctxA, testRecipe("Isolation Untouchable", "isolation untouchable ingredient"))
		if err != nil {
			t.Fatalf("save as A: %v", err)
		}

		for _, tc := range []struct {
			name string
			stmt string
		}{
			{"update", `UPDATE recipes SET name = 'hijacked' WHERE uuid = $1`},
			{"delete", `DELETE FROM recipes WHERE uuid = $1`},
		} {
			var affected int64
			if err := inTestHome(sqlDB, homeB, func(tx *sql.Tx) error {
				res, err := tx.Exec(tc.stmt, saved.UUID)
				if err != nil {
					return err
				}
				affected, err = res.RowsAffected()
				return err
			}); err != nil {
				t.Fatalf("B's %s of A's recipe: %v", tc.name, err)
			}
			if affected != 0 {
				t.Errorf("B's %s touched %d of A's rows", tc.name, affected)
			}
		}

		got, err := recipes.GetRecipeByID(ctxA, saved.UUID)
		if err != nil {
			t.Fatalf("A re-read its own recipe: %v", err)
		}
		if got.Name != "Isolation Untouchable" {
			t.Errorf("A's recipe is now named %q", got.Name)
		}
	})

	// The regression the policies are written around. app.home_id is
	// transaction-local, and a custom GUC reverts to the empty string rather
	// than to NULL once a session has set it, so the connection this returns to
	// the pool carries ''. Casting that to uuid raises; NULLIF filters instead.
	t.Run("a pooled connection between transactions reads nothing", func(t *testing.T) {
		ctx := context.Background()

		conn, err := sqlDB.Conn(ctx)
		if err != nil {
			t.Fatalf("pin a connection: %v", err)
		}
		defer conn.Close()

		tx, err := conn.BeginTx(ctx, nil)
		if err != nil {
			t.Fatalf("begin: %v", err)
		}
		if _, err := tx.ExecContext(ctx, `SELECT set_config('app.home_id', $1, true)`, homeA.String()); err != nil {
			t.Fatalf("publish home A: %v", err)
		}
		var inside int
		if err := tx.QueryRowContext(ctx, `SELECT count(*) FROM recipes`).Scan(&inside); err != nil {
			t.Fatalf("count inside the transaction: %v", err)
		}
		if err := tx.Commit(); err != nil {
			t.Fatalf("commit: %v", err)
		}
		if inside == 0 {
			t.Fatalf("home A saw no recipes of its own, so the count below proves nothing")
		}

		var after int
		if err := conn.QueryRowContext(ctx, `SELECT count(*) FROM recipes`).Scan(&after); err != nil {
			t.Fatalf("the same connection outside a transaction raised %v, want zero rows", err)
		}
		if after != 0 {
			t.Errorf("a connection with no live transaction read %d recipes", after)
		}
	})

	t.Run("two homes each hold an ingredient of the same name", func(t *testing.T) {
		const shared = "isolation duplicate ingredient"

		for _, home := range []uuid.UUID{homeA, homeB} {
			if err := inTestHome(sqlDB, home, func(tx *sql.Tx) error {
				_, err := tx.Exec(`INSERT INTO ingredients (name) VALUES ($1)`, shared)
				return err
			}); err != nil {
				t.Fatalf("insert %q into %s: %v", shared, home, err)
			}
		}

		for _, home := range []uuid.UUID{homeA, homeB} {
			n := countInHome(t, sqlDB, home, `SELECT count(*) FROM ingredients WHERE name = $1`, shared)
			if n != 1 {
				t.Errorf("home %s sees %d ingredients called %q, want 1", home, n, shared)
			}
		}
	})

	// Phase 3 left this open: the delete matches on lower(name) with no home
	// predicate, so while the keys were globally unique one home's removal took
	// every home's. The policy scopes the statement.
	t.Run("removing a shopping list item leaves another home's alone", func(t *testing.T) {
		const item = "isolation removable item"

		for _, ctx := range []context.Context{ctxA, ctxB} {
			if err := pantryRepo.AddCustomShoppingItem(ctx, item); err != nil {
				t.Fatalf("add %q: %v", item, err)
			}
		}

		if err := pantryRepo.RemoveCustomShoppingItem(ctxA, item); err != nil {
			t.Fatalf("A removes %q: %v", item, err)
		}

		if got := countInHome(t, sqlDB, homeA, `SELECT count(*) FROM shopping_list_items WHERE name = $1`, item); got != 0 {
			t.Errorf("A still holds %d of %q", got, item)
		}
		if got := countInHome(t, sqlDB, homeB, `SELECT count(*) FROM shopping_list_items WHERE name = $1`, item); got != 1 {
			t.Errorf("B holds %d of %q after A removed its own, want 1", got, item)
		}
	})

	// The mirror of the above, also from Phase 3: the dedupe subselect saw every
	// home, so a second home adding what a first home already had got a success
	// response and no row.
	t.Run("adding a shopping list item another home holds writes a row", func(t *testing.T) {
		const item = "isolation duplicate item"

		if err := pantryRepo.AddCustomShoppingItem(ctxA, item); err != nil {
			t.Fatalf("A adds %q: %v", item, err)
		}
		if err := pantryRepo.AddCustomShoppingItem(ctxB, item); err != nil {
			t.Fatalf("B adds %q: %v", item, err)
		}

		for _, home := range []uuid.UUID{homeA, homeB} {
			n := countInHome(t, sqlDB, home, `SELECT count(*) FROM shopping_list_items WHERE name = $1`, item)
			if n != 1 {
				t.Errorf("home %s holds %d of %q, want 1", home, n, item)
			}
		}
	})

	// The third of Phase 3's cross-home deletes: the pantry delete resolves its
	// ingredient through a subselect that used to read every home.
	t.Run("removing from the pantry leaves another home's alone", func(t *testing.T) {
		const ingredient = "isolation pantry ingredient"

		for i, ctx := range []context.Context{ctxA, ctxB} {
			if _, err := recipes.SaveRecipe(ctx, testRecipe(fmt.Sprintf("Isolation Pantry %d", i), ingredient)); err != nil {
				t.Fatalf("seed recipe %d: %v", i, err)
			}
			if err := pantryRepo.AddToPantry(ctx, ingredient); err != nil {
				t.Fatalf("stock pantry %d: %v", i, err)
			}
		}

		if err := pantryRepo.RemoveFromPantry(ctxA, ingredient); err != nil {
			t.Fatalf("A empties its pantry: %v", err)
		}

		stockA, err := pantryRepo.ListPantry(ctxA)
		if err != nil {
			t.Fatalf("list A's pantry: %v", err)
		}
		for _, item := range stockA {
			if item.Ingredient == ingredient {
				t.Errorf("A still stocks %q", ingredient)
			}
		}

		stockB, err := pantryRepo.ListPantry(ctxB)
		if err != nil {
			t.Fatalf("list B's pantry: %v", err)
		}
		found := false
		for _, item := range stockB {
			if item.Ingredient == ingredient {
				found = true
			}
		}
		if !found {
			t.Errorf("A's removal emptied B's pantry of %q too", ingredient)
		}
	})

	// Phase 3 recorded that ingredient resolution read every home, so a second
	// home's save reused the first home's row and the resulting recipe_ingredient
	// pointed outside its own home. The policy is what stops it.
	t.Run("an ingredient another home named resolves to this home's own row", func(t *testing.T) {
		const shared = "isolation resolved ingredient"

		if _, err := recipes.SaveRecipe(ctxA, testRecipe("Isolation Resolve A", shared)); err != nil {
			t.Fatalf("save as A: %v", err)
		}
		savedB, err := recipes.SaveRecipe(ctxB, testRecipe("Isolation Resolve B", shared))
		if err != nil {
			t.Fatalf("save as B: %v", err)
		}

		for _, home := range []uuid.UUID{homeA, homeB} {
			n := countInHome(t, sqlDB, home, `SELECT count(*) FROM ingredients WHERE name = $1`, shared)
			if n != 1 {
				t.Errorf("home %s sees %d ingredients called %q, want its own one", home, n, shared)
			}
		}

		// B's recipe must reach its ingredient from inside B. A join that
		// crossed homes would come back empty here rather than wrong.
		n := countInHome(t, sqlDB, homeB,
			`SELECT count(*) FROM recipe_ingredient ri
			 INNER JOIN ingredients i ON i.uuid = ri.ingredient_id
			 WHERE ri.recipe_id = $1 AND i.name = $2`,
			savedB.UUID, shared)
		if n != 1 {
			t.Errorf("B's recipe reaches %d rows for %q, want 1", n, shared)
		}
	})

	// The pantry resolves a name to an ingredient before it writes. That lookup
	// is now scoped, so a name only another home owns is an error rather than a
	// write against somebody else's row.
	t.Run("stocking an ingredient only another home owns is refused", func(t *testing.T) {
		const onlyA = "isolation private ingredient"

		if _, err := recipes.SaveRecipe(ctxA, testRecipe("Isolation Private", onlyA)); err != nil {
			t.Fatalf("save as A: %v", err)
		}

		err := pantryRepo.AddToPantry(ctxB, onlyA)
		if !errors.Is(err, pantry.ErrIngredientNotFound) {
			t.Errorf("B stocking A's ingredient returned %v, want an unknown-ingredient error", err)
		}
	})
}
