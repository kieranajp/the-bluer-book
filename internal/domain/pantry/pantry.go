package pantry

import "time"

// PantryItem is presence-only: the ingredient is identified by its name, which
// is unique in the ingredients table.
type PantryItem struct {
	Ingredient string    `json:"ingredient"`
	AddedAt    time.Time `json:"addedAt,omitempty"`
}

// Checking off a meal-plan item stocks the pantry; checking off a custom
// (free-text) item simply deletes it.
type ShoppingSource string

const (
	ShoppingSourceMealPlan ShoppingSource = "meal_plan"
	ShoppingSourceCustom   ShoppingSource = "custom"
)

// ShoppingListItem is one line on the shopping list. Source tells the client
// (and the check-off behaviour) which kind it is.
type ShoppingListItem struct {
	Name   string         `json:"name"`
	Source ShoppingSource `json:"source"`
}
