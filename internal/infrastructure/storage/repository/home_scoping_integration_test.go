package repository

import (
	"context"
	"database/sql"
	"errors"
	"os"
	"testing"

	"github.com/google/uuid"
	_ "github.com/lib/pq"

	"github.com/kieranajp/the-bluer-book/internal/domain/recipe"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/auth"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
)

// openTestDB connects to the database named by BLUER_BOOK_TEST_DSN, skipping
// the suite when none is set so an ordinary `go test ./...` stays offline.
func openTestDB(t *testing.T) *sql.DB {
	t.Helper()

	dsn := os.Getenv("BLUER_BOOK_TEST_DSN")
	if dsn == "" {
		t.Skip("BLUER_BOOK_TEST_DSN not set")
	}

	sqlDB, err := sql.Open("postgres", dsn)
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	if err := sqlDB.Ping(); err != nil {
		t.Fatalf("ping: %v", err)
	}
	t.Cleanup(func() { sqlDB.Close() })
	return sqlDB
}

// skipUnlessUnrestricted leaves this suite to the owning role: its assertions
// read tenant tables on the bare pool, outside any transaction, which the
// isolation policies would otherwise stop. TestIsolation wants the bound connection.
func skipUnlessUnrestricted(t *testing.T, sqlDB *sql.DB) {
	t.Helper()

	if role, bound := rlsBinds(t, sqlDB); bound {
		t.Skipf("connected as %q, which row-level security binds: these assertions read tenant tables outside a transaction", role)
	}
}

// makeHome creates a home to act as, and removes it afterwards. Every tenant
// table cascades from homes, so the delete takes the test's rows with it.
func makeHome(t *testing.T, sqlDB *sql.DB, name string) uuid.UUID {
	t.Helper()

	id := uuid.New()
	if _, err := sqlDB.Exec(`INSERT INTO homes (uuid, name) VALUES ($1, $2)`, id, name); err != nil {
		t.Fatalf("create home %s: %v", name, err)
	}
	t.Cleanup(func() {
		if _, err := sqlDB.Exec(`DELETE FROM homes WHERE uuid = $1`, id); err != nil {
			t.Errorf("clean up home %s: %v", name, err)
		}
	})
	return id
}

// dropTestVocabulary removes the label and unit a saved recipe creates. Both
// tables are global, so deleting the home does not cascade to them and a run
// against a real database would otherwise leave them in every home's lists.
func dropTestVocabulary(t *testing.T, sqlDB *sql.DB) {
	t.Helper()

	t.Cleanup(func() {
		if _, err := sqlDB.Exec(`DELETE FROM labels WHERE type = $1 AND name = $2`, testLabelType, testLabelName); err != nil {
			t.Errorf("clean up label: %v", err)
		}
		if _, err := sqlDB.Exec(`DELETE FROM units WHERE name = $1`, testUnitName); err != nil {
			t.Errorf("clean up unit: %v", err)
		}
	})
}

// inTestHome is InHomeTx's SQL, without the repository: a transaction that has
// published a home, for assertions about the column default itself.
func inTestHome(sqlDB *sql.DB, home uuid.UUID, fn func(tx *sql.Tx) error) error {
	tx, err := sqlDB.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	if _, err := tx.Exec(`SELECT set_config('app.home_id', $1, true)`, home.String()); err != nil {
		return err
	}
	if err := fn(tx); err != nil {
		return err
	}
	return tx.Commit()
}

// Vocabulary these tests create in the global units and labels tables, named so
// a leak is obvious and so dropTestVocabulary can find it again.
const (
	testUnitName  = "scoping test unit"
	testLabelType = "cuisine"
	testLabelName = "scoping test label"
)

func testRecipe(name, ingredient string) recipe.Recipe {
	return recipe.Recipe{
		Name:        name,
		Description: "written by TestHomeScoping",
		Steps:       []recipe.Step{{Order: 1, Description: "wait"}},
		Ingredients: []recipe.RecipeIngredient{{
			Ingredient: recipe.Ingredient{Name: ingredient},
			Unit:       recipe.Unit{Name: testUnitName, Abbreviation: "stu"},
			Quantity:   1,
		}},
		Labels: []recipe.Label{{Type: testLabelType, Name: testLabelName}},
	}
}

// TestHomeScoping proves the column default does the work the queries no longer
// do: a write lands in the home its context names, and a call with no home
// reaches the database not at all.
func TestHomeScoping(t *testing.T) {
	sqlDB := openTestDB(t)
	skipUnlessUnrestricted(t, sqlDB)

	log := logger.New(logger.LogLevelError)
	repo := NewRecipeRepository(sqlDB, log)
	dropTestVocabulary(t, sqlDB)

	homeA := makeHome(t, sqlDB, "scoping A")
	homeB := makeHome(t, sqlDB, "scoping B")

	t.Run("a save lands in the home its context names", func(t *testing.T) {
		saved, err := repo.SaveRecipe(auth.WithHome(context.Background(), homeA), testRecipe("Scoped A", "scoped ingredient A"))
		if err != nil {
			t.Fatalf("save: %v", err)
		}

		// Read the stamp back outside the repository: nothing in the write path
		// mentioned a home, so the column default is the only thing that could
		// have set it.
		var got uuid.UUID
		if err := sqlDB.QueryRow(`SELECT home_id FROM recipes WHERE uuid = $1`, saved.UUID).Scan(&got); err != nil {
			t.Fatalf("read back home_id: %v", err)
		}
		if got != homeA {
			t.Errorf("recipe landed in home %s, want %s", got, homeA)
		}

		for _, table := range []string{"steps", "recipe_ingredient", "recipe_label"} {
			var wrong int
			q := `SELECT count(*) FROM ` + table + ` WHERE recipe_id = $1 AND home_id <> $2`
			if err := sqlDB.QueryRow(q, saved.UUID, homeA).Scan(&wrong); err != nil {
				t.Fatalf("count %s: %v", table, err)
			}
			if wrong != 0 {
				t.Errorf("%s: %d rows carry a home other than %s", table, wrong, homeA)
			}
		}
	})

	// Tested directly rather than through SaveRecipe: on this unbound
	// connection, ingredient lookup by name sees every home, so a save in home B
	// would find and reuse home A's row. TestIsolation asserts the policy that stops it.
	t.Run("two homes each hold an ingredient of the same name", func(t *testing.T) {
		const shared = "scoping shared ingredient"

		for _, home := range []uuid.UUID{homeA, homeB} {
			// No INSERT names a home: each row takes the one the transaction set.
			if err := inTestHome(sqlDB, home, func(tx *sql.Tx) error {
				_, err := tx.Exec(`INSERT INTO ingredients (name) VALUES ($1)`, shared)
				return err
			}); err != nil {
				t.Fatalf("insert into %s: %v", home, err)
			}
		}

		var homes int
		if err := sqlDB.QueryRow(
			`SELECT count(DISTINCT home_id) FROM ingredients WHERE name = $1 AND home_id IN ($2, $3)`,
			shared, homeA, homeB,
		).Scan(&homes); err != nil {
			t.Fatalf("count ingredient homes: %v", err)
		}
		if homes != 2 {
			t.Errorf("%q exists in %d of the two homes, want 2", shared, homes)
		}
	})

	// The photo upload is two writes that have to happen together, and the
	// handler no longer owns either of them.
	t.Run("a main photo lands in the home it was uploaded from", func(t *testing.T) {
		const url = "https://example.invalid/scoping-main.jpg"

		saved, err := repo.SaveRecipe(auth.WithHome(context.Background(), homeA), testRecipe("Scoped Photo", "scoped photo ingredient"))
		if err != nil {
			t.Fatalf("save: %v", err)
		}
		if err := repo.SetMainPhoto(auth.WithHome(context.Background(), homeA), saved.UUID, url); err != nil {
			t.Fatalf("set main photo: %v", err)
		}

		var photoID, photoHome uuid.UUID
		var entityType string
		if err := sqlDB.QueryRow(
			`SELECT uuid, home_id, entity_type FROM photos WHERE url = $1 AND entity_id = $2`,
			url, saved.UUID,
		).Scan(&photoID, &photoHome, &entityType); err != nil {
			t.Fatalf("read back the photo: %v", err)
		}
		if photoHome != homeA {
			t.Errorf("photo landed in home %s, want %s", photoHome, homeA)
		}
		if entityType != "recipe" {
			t.Errorf("photo attached to a %q, want a recipe", entityType)
		}

		var mainPhoto uuid.NullUUID
		if err := sqlDB.QueryRow(`SELECT main_photo_id FROM recipes WHERE uuid = $1`, saved.UUID).Scan(&mainPhoto); err != nil {
			t.Fatalf("read back main_photo_id: %v", err)
		}
		if !mainPhoto.Valid || mainPhoto.UUID != photoID {
			t.Errorf("recipe points at %v, want the photo %s", mainPhoto, photoID)
		}
	})

	t.Run("no home in context reaches no database", func(t *testing.T) {
		ctx := context.Background()

		if _, err := repo.SaveRecipe(ctx, testRecipe("Homeless", "homeless ingredient")); !errors.Is(err, auth.ErrNoHome) {
			t.Errorf("SaveRecipe returned %v, want %v", err, auth.ErrNoHome)
		}
		if _, _, err := repo.ListRecipes(ctx, 10, 0, "", nil, ""); !errors.Is(err, auth.ErrNoHome) {
			t.Errorf("ListRecipes returned %v, want %v", err, auth.ErrNoHome)
		}
		if _, err := repo.GetRecipeByID(ctx, uuid.New()); !errors.Is(err, auth.ErrNoHome) {
			t.Errorf("GetRecipeByID returned %v, want %v", err, auth.ErrNoHome)
		}

		var written int
		if err := sqlDB.QueryRow(`SELECT count(*) FROM recipes WHERE name = 'Homeless'`).Scan(&written); err != nil {
			t.Fatalf("count: %v", err)
		}
		if written != 0 {
			t.Errorf("a homeless save wrote %d recipes", written)
		}
	})

	t.Run("the zero home is no home", func(t *testing.T) {
		ctx := auth.WithHome(context.Background(), uuid.Nil)
		if _, err := repo.SaveRecipe(ctx, testRecipe("Nil home", "nil home ingredient")); !errors.Is(err, auth.ErrNoHome) {
			t.Errorf("SaveRecipe returned %v, want %v", err, auth.ErrNoHome)
		}
	})
}

// TestHomeScopedPantry covers the pantry repository, whose add path resolves an
// ingredient and writes it in one transaction.
func TestHomeScopedPantry(t *testing.T) {
	sqlDB := openTestDB(t)
	skipUnlessUnrestricted(t, sqlDB)

	log := logger.New(logger.LogLevelError)
	recipes := NewRecipeRepository(sqlDB, log)
	pantry := NewPantryRepository(sqlDB, log)
	dropTestVocabulary(t, sqlDB)

	homeA := makeHome(t, sqlDB, "pantry scoping A")
	ctxA := auth.WithHome(context.Background(), homeA)

	const ingredient = "pantry scoped ingredient"
	if _, err := recipes.SaveRecipe(ctxA, testRecipe("Pantry A", ingredient)); err != nil {
		t.Fatalf("seed recipe: %v", err)
	}

	if err := pantry.AddToPantry(ctxA, ingredient); err != nil {
		t.Fatalf("add to pantry: %v", err)
	}

	var got uuid.UUID
	if err := sqlDB.QueryRow(
		`SELECT p.home_id FROM pantry_items p JOIN ingredients i ON i.uuid = p.ingredient_id WHERE i.name = $1 AND p.home_id = $2`,
		ingredient, homeA,
	).Scan(&got); err != nil {
		t.Fatalf("read back pantry home_id: %v", err)
	}
	if got != homeA {
		t.Errorf("pantry item landed in home %s, want %s", got, homeA)
	}

	if err := pantry.AddToPantry(context.Background(), ingredient); !errors.Is(err, auth.ErrNoHome) {
		t.Errorf("AddToPantry with no home returned %v, want %v", err, auth.ErrNoHome)
	}
	if _, err := pantry.ListPantry(context.Background()); !errors.Is(err, auth.ErrNoHome) {
		t.Errorf("ListPantry with no home returned %v, want %v", err, auth.ErrNoHome)
	}
}
