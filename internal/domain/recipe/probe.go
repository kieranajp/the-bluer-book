package recipe

// Probe provides domain-oriented observability for recipe operations.
type Probe interface {
	RecipeCreated(name string)
	RecipeUpdated(name string)
	RecipeArchived(id string)
	RecipeRestored(id string)
	MealPlanChanged(action string, recipeID string)
	RecipeSearched(resultCount int)
	RecipeError(operation string, err error)
}
