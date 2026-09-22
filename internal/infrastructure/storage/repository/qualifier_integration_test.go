package repository

import (
	"context"
	"testing"

	"github.com/kieranajp/the-bluer-book/internal/domain/recipe"
)

// A free-text entry like "garlic cloves" should resolve to the garlic the
// book already stocks, with the count qualifier moved onto the recipe line —
// not mint a second ingredient row. Same story for plural units: "cloves"
// stores against the existing "clove" unit.
//
// Assertions read the recipe back through GetRecipeByID: the in-memory
// struct SaveRecipe returns is not re-read from the database after the
// qualifier merge.
func TestSaveRecipeSplitsQualifierFromName(t *testing.T) {
	recipes, _, _ := newRepos(t)

	saveRecipe(t, recipes, "First", ingredientLine("garlic", "clove", "", 1))
	saved := saveRecipe(t, recipes, "Second", ingredientLine("garlic cloves", "", "", 2))

	all, err := recipes.ListIngredients(context.Background())
	if err != nil {
		t.Fatalf("ListIngredients: %v", err)
	}
	if len(all) != 1 || all[0].Name != "garlic" {
		t.Fatalf("got %d ingredients (%+v), want one row: garlic", len(all), all)
	}

	got, err := recipes.GetRecipeByID(context.Background(), saved.UUID)
	if err != nil {
		t.Fatalf("GetRecipeByID: %v", err)
	}
	if got.Ingredients[0].Preparation != "cloves" {
		t.Errorf("preparation = %q, want %q moved off the name", got.Ingredients[0].Preparation, "cloves")
	}
	if unit := got.Ingredients[0].Unit.Name; unit != "clove" {
		t.Errorf("unit = %q, want the existing singular reused", unit)
	}
}

// An existing preparation is never overwritten by the stripped qualifier.
func TestSaveRecipeKeepsExistingPreparation(t *testing.T) {
	recipes, _, _ := newRepos(t)

	saveRecipe(t, recipes, "First", ingredientLine("garlic", "clove", "", 1))
	saved := saveRecipe(t, recipes, "Second", recipe.RecipeIngredient{
		Ingredient:  recipe.Ingredient{Name: "garlic cloves"},
		Quantity:    2,
		Preparation: "finely grated",
	})

	got, err := recipes.GetRecipeByID(context.Background(), saved.UUID)
	if err != nil {
		t.Fatalf("GetRecipeByID: %v", err)
	}
	if got.Ingredients[0].Preparation != "finely grated" {
		t.Errorf("preparation = %q, want the recipe's own wording kept", got.Ingredients[0].Preparation)
	}
}

// "spring onions" is a real ingredient name, not garlic-with-a-qualifier:
// nothing should be stripped when there is no qualifying noun at the end.
func TestSaveRecipeLeavesPlainNamesAlone(t *testing.T) {
	recipes, _, _ := newRepos(t)

	saved := saveRecipe(t, recipes, "Only",
		ingredientLine("spring onions", "", "", 3))

	got, err := recipes.GetRecipeByID(context.Background(), saved.UUID)
	if err != nil {
		t.Fatalf("GetRecipeByID: %v", err)
	}
	if got.Ingredients[0].Ingredient.Name != "spring onions" {
		t.Errorf("name = %q, want it stored verbatim", got.Ingredients[0].Ingredient.Name)
	}
}

// A plural unit resolves to its stored singular: quantity carries the count.
func TestSaveRecipeMapsUnitToSingular(t *testing.T) {
	recipes, _, _ := newRepos(t)

	saveRecipe(t, recipes, "First", ingredientLine("garlic", "clove", "", 1))
	saved := saveRecipe(t, recipes, "Second", ingredientLine("garlic", "cloves", "", 3))

	got, err := recipes.GetRecipeByID(context.Background(), saved.UUID)
	if err != nil {
		t.Fatalf("GetRecipeByID: %v", err)
	}
	if unit := got.Ingredients[0].Unit.Name; unit != "clove" {
		t.Errorf("unit = %q, want the stored singular", unit)
	}
}
