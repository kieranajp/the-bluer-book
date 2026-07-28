package repository

import (
	"context"
	"database/sql"
	"errors"
	"os"
	"testing"

	"github.com/kieranajp/the-bluer-book/internal/domain/pantry"
	"github.com/kieranajp/the-bluer-book/internal/domain/recipe"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/storage/db"
	_ "github.com/lib/pq"
)

// Integration tests for the ingredient write path — the code this refactor
// leans on hardest and the only part of the repository that was untested.
// Nothing here can be checked with a stub: the behaviour under test is where
// the Go and the SQL meet (case-insensitive resolution, the three-column
// primary key, orphan collection).
//
// Skipped unless BLUER_TEST_DSN points at a migrated, disposable database. CI
// has no Postgres service, so these do not run there:
//
//	BLUER_TEST_DSN='postgres://postgres:postgres@127.0.0.1:55432/bluer?sslmode=disable' go test ./internal/infrastructure/storage/repository/
func testDB(t *testing.T) (*sql.DB, *db.Queries) {
	t.Helper()
	dsn := os.Getenv("BLUER_TEST_DSN")
	if dsn == "" {
		t.Skip("BLUER_TEST_DSN not set; skipping database integration tests")
	}
	sqlDB, err := sql.Open("postgres", dsn)
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	if err := sqlDB.Ping(); err != nil {
		t.Fatalf("ping: %v", err)
	}
	t.Cleanup(func() { sqlDB.Close() })

	// Every test starts from an empty book so ordering can't matter.
	for _, stmt := range []string{
		"DELETE FROM pantry_items",
		"DELETE FROM recipe_ingredient",
		"DELETE FROM recipe_label",
		"DELETE FROM meal_plan_recipes",
		"DELETE FROM steps",
		"DELETE FROM photos",
		"DELETE FROM recipes",
		"DELETE FROM ingredient_aliases",
		"DELETE FROM ingredients",
	} {
		if _, err := sqlDB.Exec(stmt); err != nil {
			t.Fatalf("reset (%s): %v", stmt, err)
		}
	}
	return sqlDB, db.New(sqlDB)
}

func newRepos(t *testing.T) (RecipeRepository, PantryRepository, *sql.DB) {
	t.Helper()
	sqlDB, q := testDB(t)
	log := logger.New(logger.LogLevelError)
	return NewRecipeRepository(q, sqlDB, log), NewPantryRepository(q, log), sqlDB
}

func ingredientLine(name, unit, component string, qty float64) recipe.RecipeIngredient {
	return recipe.RecipeIngredient{
		Ingredient: recipe.Ingredient{Name: name},
		Unit:       recipe.Unit{Name: unit},
		Quantity:   qty,
		Component:  component,
	}
}

func saveRecipe(t *testing.T, repo RecipeRepository, name string, lines ...recipe.RecipeIngredient) *recipe.Recipe {
	t.Helper()
	saved, err := repo.SaveRecipe(context.Background(), recipe.Recipe{
		Name:        name,
		Ingredients: lines,
		Steps:       []recipe.Step{{Order: 1, Description: "cook it"}},
	})
	if err != nil {
		t.Fatalf("SaveRecipe(%q): %v", name, err)
	}
	return saved
}

// The bug this whole refactor exists for: differently-cased spellings of one
// ingredient used to become separate rows, so nothing joined up.
func TestSaveRecipeReusesIngredientsAcrossCasing(t *testing.T) {
	recipes, _, _ := newRepos(t)

	saveRecipe(t, recipes, "First", ingredientLine("Olive Oil", "tbsp", "", 2))
	saveRecipe(t, recipes, "Second", ingredientLine("olive oil", "tbsp", "", 1))
	saveRecipe(t, recipes, "Third", ingredientLine("  OLIVE OIL  ", "tbsp", "", 1))

	all, err := recipes.ListIngredients(context.Background())
	if err != nil {
		t.Fatalf("ListIngredients: %v", err)
	}
	if len(all) != 1 {
		names := make([]string, len(all))
		for i, x := range all {
			names[i] = x.Name
		}
		t.Fatalf("got %d ingredients %v, want them all to resolve to one", len(all), names)
	}
	// First writer wins the display casing; identity is the canonical form.
	if all[0].Name != "Olive Oil" || all[0].Canonical != "olive oil" {
		t.Errorf("ingredient = %+v, want display \"Olive Oil\" / canonical \"olive oil\"", all[0])
	}
}

// recipe_ingredient's key is (recipe_id, ingredient_id, component) since 00011.
// Before that, the second of these lines was silently discarded.
func TestSaveRecipeKeepsOneIngredientInTwoComponents(t *testing.T) {
	recipes, _, _ := newRepos(t)

	saved := saveRecipe(t, recipes, "Katsu",
		ingredientLine("salt", "tsp", "sauce", 1),
		ingredientLine("Salt", "tsp", "batter", 2),
	)

	got, err := recipes.GetRecipeByID(context.Background(), saved.UUID)
	if err != nil {
		t.Fatalf("GetRecipeByID: %v", err)
	}
	if len(got.Ingredients) != 2 {
		t.Fatalf("got %d ingredient lines, want both components kept", len(got.Ingredients))
	}
	byComponent := map[string]float64{}
	for _, i := range got.Ingredients {
		byComponent[i.Component] = i.Quantity
		if i.Ingredient.Canonical != "salt" {
			t.Errorf("canonical = %q, want salt", i.Ingredient.Canonical)
		}
	}
	if byComponent["sauce"] != 1 || byComponent["batter"] != 2 {
		t.Errorf("quantities by component = %v, want sauce:1 batter:2", byComponent)
	}
}

// A true repeat within one component still collapses — there's nowhere to put
// the second row — but it must not take a different component down with it.
func TestSaveRecipeCollapsesRepeatsWithinOneComponent(t *testing.T) {
	recipes, _, _ := newRepos(t)

	saved := saveRecipe(t, recipes, "Doubled",
		ingredientLine("Sugar", "g", "", 100),
		ingredientLine("sugar", "g", "", 50),
	)

	got, err := recipes.GetRecipeByID(context.Background(), saved.UUID)
	if err != nil {
		t.Fatalf("GetRecipeByID: %v", err)
	}
	if len(got.Ingredients) != 1 {
		t.Fatalf("got %d lines, want the repeat collapsed to 1", len(got.Ingredients))
	}
	if got.Ingredients[0].Quantity != 100 {
		t.Errorf("quantity = %v, want the first line's 100", got.Ingredients[0].Quantity)
	}
}

// UpdateRecipe deletes and recreates the ingredient links, so a renamed
// ingredient used to be stranded in the table (and in the autocomplete) forever.
func TestUpdateRecipeCollectsOrphanedIngredients(t *testing.T) {
	recipes, _, _ := newRepos(t)
	ctx := context.Background()

	saved := saveRecipe(t, recipes, "Typo", ingredientLine("corriander", "g", "", 10))

	_, err := recipes.UpdateRecipe(ctx, saved.UUID, recipe.Recipe{
		Name:        "Typo",
		Ingredients: []recipe.RecipeIngredient{ingredientLine("coriander", "g", "", 10)},
		Steps:       []recipe.Step{{Order: 1, Description: "cook it"}},
	})
	if err != nil {
		t.Fatalf("UpdateRecipe: %v", err)
	}

	all, err := recipes.ListIngredients(ctx)
	if err != nil {
		t.Fatalf("ListIngredients: %v", err)
	}
	if len(all) != 1 || all[0].Name != "coriander" {
		t.Fatalf("ingredients = %+v, want only the corrected spelling", all)
	}
}

func TestPantryResolvesNamesAndReportsUnknownOnes(t *testing.T) {
	recipes, pantryRepo, _ := newRepos(t)
	ctx := context.Background()

	saveRecipe(t, recipes, "Roast", ingredientLine("Olive Oil", "tbsp", "", 2))

	// Added under one casing, removed under another — both must resolve.
	if err := pantryRepo.AddToPantry(ctx, "olive oil"); err != nil {
		t.Fatalf("AddToPantry: %v", err)
	}
	items, err := pantryRepo.ListPantry(ctx)
	if err != nil {
		t.Fatalf("ListPantry: %v", err)
	}
	if len(items) != 1 || items[0].Ingredient != "Olive Oil" || items[0].Canonical != "olive oil" {
		t.Fatalf("pantry = %+v, want the one ingredient with both forms", items)
	}

	// Idempotent: adding again must not duplicate.
	if err := pantryRepo.AddToPantry(ctx, "OLIVE OIL"); err != nil {
		t.Fatalf("AddToPantry (repeat): %v", err)
	}
	if items, _ = pantryRepo.ListPantry(ctx); len(items) != 1 {
		t.Fatalf("pantry = %+v after repeat add, want 1 item", items)
	}

	// The original bug: this used to report success and change nothing.
	err = pantryRepo.AddToPantry(ctx, "unobtainium")
	if err == nil {
		t.Fatal("AddToPantry(unknown) = nil, want ErrIngredientNotFound")
	}
	var notFound pantry.IngredientNotFoundError
	if !errors.As(err, &notFound) {
		t.Fatalf("AddToPantry(unknown) error = %v, want IngredientNotFoundError", err)
	}

	if err := pantryRepo.RemoveFromPantry(ctx, "  Olive Oil "); err != nil {
		t.Fatalf("RemoveFromPantry: %v", err)
	}
	if items, _ = pantryRepo.ListPantry(ctx); len(items) != 0 {
		t.Fatalf("pantry = %+v after removal, want empty", items)
	}
}

// Aliases are what make the pantry tolerant of whatever the chat agent types.
func TestPantryResolvesThroughAliases(t *testing.T) {
	recipes, pantryRepo, sqlDB := newRepos(t)
	ctx := context.Background()

	saveRecipe(t, recipes, "Salsa", ingredientLine("fresh coriander", "g", "", 20))
	if _, err := sqlDB.Exec(`
		INSERT INTO ingredient_aliases (alias, ingredient_id)
		SELECT 'cilantro', uuid FROM ingredients WHERE canonical_name = 'fresh coriander'`); err != nil {
		t.Fatalf("seed alias: %v", err)
	}

	if err := pantryRepo.AddToPantry(ctx, "Cilantro"); err != nil {
		t.Fatalf("AddToPantry via alias: %v", err)
	}
	items, err := pantryRepo.ListPantry(ctx)
	if err != nil {
		t.Fatalf("ListPantry: %v", err)
	}
	if len(items) != 1 || items[0].Ingredient != "fresh coriander" {
		t.Fatalf("pantry = %+v, want the alias to resolve to fresh coriander", items)
	}
}

// Staples are assumed in the cupboard, so they never reach the shopping list.
func TestShoppingListSkipsStaplesAndStockedItems(t *testing.T) {
	recipes, pantryRepo, _ := newRepos(t)
	ctx := context.Background()

	saved := saveRecipe(t, recipes, "Dinner",
		ingredientLine("Salt", "tsp", "", 1),
		ingredientLine("Onion", "", "", 2),
		ingredientLine("Rice", "g", "", 200),
	)
	if err := recipes.AddToMealPlan(ctx, saved.UUID); err != nil {
		t.Fatalf("AddToMealPlan: %v", err)
	}
	if err := pantryRepo.SetStaple(ctx, "salt", true); err != nil {
		t.Fatalf("SetStaple: %v", err)
	}
	if err := pantryRepo.AddToPantry(ctx, "onion"); err != nil {
		t.Fatalf("AddToPantry: %v", err)
	}
	shortfall, err := pantryRepo.ShoppingList(ctx)
	if err != nil {
		t.Fatalf("ShoppingList: %v", err)
	}
	if len(shortfall) != 1 || shortfall[0] != "Rice" {
		t.Fatalf("shopping list = %v, want only [Rice] — salt is a staple, onion is stocked", shortfall)
	}
}
