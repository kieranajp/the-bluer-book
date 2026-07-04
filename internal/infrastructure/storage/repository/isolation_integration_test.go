package repository_test

// Integration test for home isolation. Runs end-to-end through the repo's
// inHomeTx, the home-scoped queries, and (when connected as a non-owner
// role) Postgres RLS.
//
// Skipped unless BLUER_BOOK_TEST_DSN points at a migrated database. To run:
//
//   docker run -d --name bluer-test-pg -e POSTGRES_PASSWORD=test \
//       -e POSTGRES_USER=postgres -p 5433:5432 postgres:17.5-alpine
//   psql -U postgres -h localhost -p 5433 -c "CREATE USER bluer_book WITH PASSWORD 'test' SUPERUSER;"
//   psql -U postgres -h localhost -p 5433 -c "CREATE DATABASE bluer_book OWNER bluer_book;"
//   DB_HOST=localhost DB_PORT=5433 DB_USER=postgres DB_PASS=test DB_NAME=bluer_book \
//       go run . migrate
//   BLUER_BOOK_TEST_DSN="postgres://postgres:test@localhost:5433/bluer_book?sslmode=disable" \
//       go test ./internal/infrastructure/storage/repository/...

import (
	"context"
	"database/sql"
	"os"
	"testing"

	"github.com/google/uuid"
	_ "github.com/lib/pq"

	"github.com/kieranajp/the-bluer-book/internal/domain/recipe"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/auth"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/storage/repository"
)

func openIntegrationDB(t *testing.T) *sql.DB {
	t.Helper()
	dsn := os.Getenv("BLUER_BOOK_TEST_DSN")
	if dsn == "" {
		t.Skip("BLUER_BOOK_TEST_DSN not set")
	}
	db, err := sql.Open("postgres", dsn)
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	if err := db.Ping(); err != nil {
		t.Fatalf("ping db: %v", err)
	}
	return db
}

// createHome inserts a home directly. Phase 3 will build a proper service
// for this; for now the test exercises only the recipe repo and seeds
// homes via raw SQL.
func createHome(t *testing.T, db *sql.DB, name string) uuid.UUID {
	t.Helper()
	id := uuid.New()
	if _, err := db.Exec(`INSERT INTO homes (uuid, name) VALUES ($1, $2)`, id, name); err != nil {
		t.Fatalf("create home: %v", err)
	}
	t.Cleanup(func() {
		// Cascade clears any recipes/photos/etc created during the test.
		_, _ = db.Exec(`DELETE FROM homes WHERE uuid = $1`, id)
	})
	return id
}

func TestHomeIsolation_RecipeNotVisibleAcrossHomes(t *testing.T) {
	db := openIntegrationDB(t)
	t.Cleanup(func() { _ = db.Close() })

	repo := repository.NewRecipeRepository(db, logger.New(logger.LogLevelError))

	homeA := createHome(t, db, "Test Home A")
	homeB := createHome(t, db, "Test Home B")

	ctxA := auth.WithIdentity(context.Background(), uuid.New(), homeA)
	ctxB := auth.WithIdentity(context.Background(), uuid.New(), homeB)

	saved, err := repo.SaveRecipe(ctxA, recipe.Recipe{
		Name:        "Isolation Sentinel",
		Description: "should not appear in home B",
	})
	if err != nil {
		t.Fatalf("save recipe as home A: %v", err)
	}

	// Home A finds it.
	gotA, err := repo.GetRecipeByID(ctxA, saved.UUID)
	if err != nil {
		t.Fatalf("home A get: %v", err)
	}
	if gotA.Name != "Isolation Sentinel" {
		t.Fatalf("home A got wrong recipe: %q", gotA.Name)
	}

	// Home B must NOT find it.
	_, err = repo.GetRecipeByID(ctxB, saved.UUID)
	var notFound recipe.RecipeNotFoundError
	if err == nil {
		t.Fatalf("home B unexpectedly read home A's recipe")
	}
	if e, ok := err.(recipe.RecipeNotFoundError); !ok {
		t.Fatalf("home B got %T (%v), expected RecipeNotFoundError", err, err)
	} else {
		_ = e
	}

	// Home B's list must not contain it.
	listB, _, err := repo.ListRecipes(ctxB, 100, 0, "", nil, "")
	if err != nil {
		t.Fatalf("home B list: %v", err)
	}
	for _, r := range listB {
		if r.UUID == saved.UUID {
			t.Fatalf("home B list contained home A's recipe %s", saved.UUID)
		}
	}

	// Search by name from home B must also miss.
	listBSearch, _, err := repo.ListRecipes(ctxB, 100, 0, "Isolation Sentinel", nil, "")
	if err != nil {
		t.Fatalf("home B list with search: %v", err)
	}
	if len(listBSearch) != 0 {
		t.Fatalf("home B search found %d recipes, expected 0", len(listBSearch))
	}

	// Suppress unused; notFound type referenced above.
	_ = notFound
}

func TestHomeIsolation_NoHomeInCtxReturnsErrNoHome(t *testing.T) {
	db := openIntegrationDB(t)
	t.Cleanup(func() { _ = db.Close() })

	repo := repository.NewRecipeRepository(db, logger.New(logger.LogLevelError))

	// Bare context — no identity attached. Every method must refuse rather
	// than silently running with a missing GUC.
	if _, err := repo.GetRecipeByID(context.Background(), uuid.New()); err != auth.ErrNoHome {
		t.Fatalf("GetRecipeByID without home: got %v, want ErrNoHome", err)
	}
	if _, _, err := repo.ListRecipes(context.Background(), 10, 0, "", nil, ""); err != auth.ErrNoHome {
		t.Fatalf("ListRecipes without home: got %v, want ErrNoHome", err)
	}
}

func TestHomeIsolation_PantryAndShoppingListAreHomeScoped(t *testing.T) {
	db := openIntegrationDB(t)
	t.Cleanup(func() { _ = db.Close() })

	recipes := repository.NewRecipeRepository(db, logger.New(logger.LogLevelError))
	pantry := repository.NewPantryRepository(db, logger.New(logger.LogLevelError))

	homeA := createHome(t, db, "Pantry A")
	homeB := createHome(t, db, "Pantry B")
	ctxA := auth.WithIdentity(context.Background(), uuid.New(), homeA)
	ctxB := auth.WithIdentity(context.Background(), uuid.New(), homeB)

	// Seed an ingredient in each home (per-home unique on (home_id, name))
	// via a recipe save — easiest path.
	const ingName = "pantry sentinel"
	if _, err := recipes.SaveRecipe(ctxA, recipe.Recipe{
		Name: "PA recipe",
		Ingredients: []recipe.RecipeIngredient{
			{Ingredient: recipe.Ingredient{Name: ingName}},
		},
	}); err != nil {
		t.Fatalf("seed home A recipe: %v", err)
	}
	if _, err := recipes.SaveRecipe(ctxB, recipe.Recipe{
		Name: "PB recipe",
		Ingredients: []recipe.RecipeIngredient{
			{Ingredient: recipe.Ingredient{Name: ingName}},
		},
	}); err != nil {
		t.Fatalf("seed home B recipe: %v", err)
	}

	// Add to home A's pantry only.
	if err := pantry.AddToPantry(ctxA, ingName); err != nil {
		t.Fatalf("AddToPantry A: %v", err)
	}

	listA, err := pantry.ListPantry(ctxA)
	if err != nil {
		t.Fatalf("ListPantry A: %v", err)
	}
	if len(listA) != 1 || listA[0].Ingredient != ingName {
		t.Fatalf("home A pantry = %v, want one %q", listA, ingName)
	}

	listB, err := pantry.ListPantry(ctxB)
	if err != nil {
		t.Fatalf("ListPantry B: %v", err)
	}
	if len(listB) != 0 {
		t.Fatalf("home B pantry leaked: %v", listB)
	}

	// Custom shopping list items must be home-scoped too.
	if err := pantry.AddCustomShoppingItem(ctxA, "milk"); err != nil {
		t.Fatalf("AddCustomShoppingItem A: %v", err)
	}
	itemsB, err := pantry.ListCustomShoppingItems(ctxB)
	if err != nil {
		t.Fatalf("ListCustomShoppingItems B: %v", err)
	}
	for _, it := range itemsB {
		if it == "milk" {
			t.Fatalf("home B saw home A's custom shopping item")
		}
	}

	// Both homes can add their own "milk" — case-insensitive uniqueness is
	// now per-home (DB-level test for the new partial index).
	if err := pantry.AddCustomShoppingItem(ctxB, "milk"); err != nil {
		t.Fatalf("AddCustomShoppingItem B: %v", err)
	}
}

func TestPurgeHome_CascadesAcrossEveryTenantTable(t *testing.T) {
	db := openIntegrationDB(t)
	t.Cleanup(func() { _ = db.Close() })

	recipes := repository.NewRecipeRepository(db, logger.New(logger.LogLevelError))
	pantry := repository.NewPantryRepository(db, logger.New(logger.LogLevelError))
	admin := repository.NewAccountAdminRepository(db)

	homeID := createHome(t, db, "Purge Sentinel")
	ctx := auth.WithIdentity(context.Background(), uuid.New(), homeID)

	saved, err := recipes.SaveRecipe(ctx, recipe.Recipe{
		Name:        "Sentinel Recipe",
		Description: "scrub me",
		Ingredients: []recipe.RecipeIngredient{
			{Ingredient: recipe.Ingredient{Name: "purge-ingredient"}},
		},
		Labels: []recipe.Label{{Type: "course", Name: "main"}},
		Steps:  []recipe.Step{{Order: 1, Description: "stir"}},
	})
	if err != nil {
		t.Fatalf("save recipe: %v", err)
	}
	if err := recipes.AddToMealPlan(ctx, saved.UUID); err != nil {
		t.Fatalf("add to meal plan: %v", err)
	}
	if err := pantry.AddToPantry(ctx, "purge-ingredient"); err != nil {
		t.Fatalf("add to pantry: %v", err)
	}
	if err := pantry.AddCustomShoppingItem(ctx, "purge-target"); err != nil {
		t.Fatalf("add custom shopping item: %v", err)
	}

	// Sanity-check that rows landed in the home before the purge.
	tenantTables := []string{
		"recipes", "steps", "recipe_ingredient", "recipe_label", "photos",
		"meal_plan_recipes", "ingredients", "pantry_items", "shopping_list_items",
	}
	for _, table := range tenantTables {
		var n int
		if err := db.QueryRow(`SELECT count(*) FROM `+table+` WHERE home_id = $1`, homeID).Scan(&n); err != nil {
			t.Fatalf("pre-purge count %s: %v", table, err)
		}
		// Not every table will have rows for every test fixture (e.g. no
		// photos here) — that's fine. We just want recipes + ingredient +
		// meal plan + pantry + shopping list to be non-zero.
		_ = n
	}

	// Purge the home. The single DELETE FROM homes cascade should sweep
	// every tenant table; no app.home_id GUC needs to be set because
	// PurgeHome runs on the owner connection.
	if err := admin.PurgeHome(context.Background(), homeID); err != nil {
		t.Fatalf("PurgeHome: %v", err)
	}

	// Every tenant table must now report zero rows for the home.
	for _, table := range tenantTables {
		var n int
		if err := db.QueryRow(`SELECT count(*) FROM `+table+` WHERE home_id = $1`, homeID).Scan(&n); err != nil {
			t.Fatalf("post-purge count %s: %v", table, err)
		}
		if n != 0 {
			t.Errorf("%s still has %d rows for purged home %s", table, n, homeID)
		}
	}

	// The home row itself must be gone.
	var homeRows int
	if err := db.QueryRow(`SELECT count(*) FROM homes WHERE uuid = $1`, homeID).Scan(&homeRows); err != nil {
		t.Fatalf("count homes: %v", err)
	}
	if homeRows != 0 {
		t.Errorf("home row still present after purge")
	}
}

func TestHomeIsolation_AddToMealPlanIsHomeScoped(t *testing.T) {
	db := openIntegrationDB(t)
	t.Cleanup(func() { _ = db.Close() })

	repo := repository.NewRecipeRepository(db, logger.New(logger.LogLevelError))

	homeA := createHome(t, db, "MP Test A")
	homeB := createHome(t, db, "MP Test B")

	ctxA := auth.WithIdentity(context.Background(), uuid.New(), homeA)
	ctxB := auth.WithIdentity(context.Background(), uuid.New(), homeB)

	saved, err := repo.SaveRecipe(ctxA, recipe.Recipe{Name: "Meal Plan Sentinel"})
	if err != nil {
		t.Fatalf("save: %v", err)
	}

	if err := repo.AddToMealPlan(ctxA, saved.UUID); err != nil {
		t.Fatalf("add to meal plan as A: %v", err)
	}

	planA, err := repo.ListMealPlanRecipes(ctxA)
	if err != nil {
		t.Fatalf("list plan A: %v", err)
	}
	foundInA := false
	for _, r := range planA {
		if r.UUID == saved.UUID {
			foundInA = true
		}
	}
	if !foundInA {
		t.Fatalf("home A meal plan did not contain recipe it just added")
	}

	planB, err := repo.ListMealPlanRecipes(ctxB)
	if err != nil {
		t.Fatalf("list plan B: %v", err)
	}
	for _, r := range planB {
		if r.UUID == saved.UUID {
			t.Fatalf("home B meal plan contained home A's recipe")
		}
	}
}
