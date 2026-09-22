package repository

import (
	"testing"
)

// A free-text entry like "garlic cloves" should resolve to the garlic the
// book already stocks, with the count qualifier becoming the unit — not mint
// a second ingredient row.
//
// Assertions read the recipe back through GetRecipeByID: the in-memory
// struct SaveRecipe returns is not re-read from the database after the
// qualifier merge.
func TestSaveRecipeSplitsQualifierFromName(t *testing.T) {
	recipes, _, _ := newRepos(t)

	ctx, recipes := scopedRepo(t)

	saveRecipe(t, recipes, ctx, "First", ingredientLine("garlic", "clove", "", 1))
	saved := saveRecipe(t, recipes, ctx, "Second", ingredientLine("garlic cloves", "", "", 2))

	all, err := recipes.ListIngredients(ctx)
	if err != nil {
		t.Fatalf("ListIngredients: %v", err)
	}
	if len(all) != 1 || all[0].Name != "garlic" {
		t.Fatalf("got %d ingredients (%+v), want one row: garlic", len(all), all)
	}

	got, err := recipes.GetRecipeByID(ctx, saved.UUID)
	if err != nil {
		t.Fatalf("GetRecipeByID: %v", err)
	}
	if unit := got.Ingredients[0].Unit.Name; unit != "clove" {
		t.Errorf("unit = %q, want the singular of the stripped qualifier", unit)
	}
	if prep := got.Ingredients[0].Preparation; prep != "" {
		t.Errorf("preparation = %q, want it left empty — \"cloves\" is a unit, not a preparation", prep)
	}
}

// A qualifier never clobbers a unit the recipe did specify.
func TestSaveRecipeKeepsSpecifiedUnit(t *testing.T) {
	recipes, _, _ := newRepos(t)

	ctx, recipes := scopedRepo(t)

	saveRecipe(t, recipes, ctx, "First", ingredientLine("garlic", "clove", "", 1))
	saved := saveRecipe(t, recipes, ctx, "Second", ingredientLine("garlic cloves", "tbsp", "", 2))

	got, err := recipes.GetRecipeByID(ctx, saved.UUID)
	if err != nil {
		t.Fatalf("GetRecipeByID: %v", err)
	}
	if unit := got.Ingredients[0].Unit.Name; unit != "tbsp" {
		t.Errorf("unit = %q, want the recipe's own unit kept", unit)
	}
}

// "spring onions" is a real ingredient name, not garlic-with-a-qualifier:
// nothing should be stripped when there is no qualifying noun at the end.
func TestSaveRecipeLeavesPlainNamesAlone(t *testing.T) {
	ctx, recipes := scopedRepo(t)

	saved := saveRecipe(t, recipes, ctx, "Only",
		ingredientLine("spring onions", "", "", 3))

	got, err := recipes.GetRecipeByID(ctx, saved.UUID)
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

	ctx, recipes := scopedRepo(t)

	saveRecipe(t, recipes, ctx, "First", ingredientLine("garlic", "clove", "", 1))
	saved := saveRecipe(t, recipes, ctx, "Second", ingredientLine("garlic", "cloves", "", 3))

	got, err := recipes.GetRecipeByID(ctx, saved.UUID)
	if err != nil {
		t.Fatalf("GetRecipeByID: %v", err)
	}
	if unit := got.Ingredients[0].Unit.Name; unit != "clove" {
		t.Errorf("unit = %q, want the stored singular", unit)
	}
}
