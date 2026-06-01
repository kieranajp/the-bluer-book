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
