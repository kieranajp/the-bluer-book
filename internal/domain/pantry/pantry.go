package pantry

import "time"

// PantryItem records that the user currently has a given ingredient at home.
// Presence-only (v1).
//
// Ingredient is the display name; Canonical is what clients should match on
// when deciding whether a recipe's ingredient is in stock. Matching on the
// display name is what made "Salt" in the pantry fail to tick the "salt" row
// in a recipe.
type PantryItem struct {
	Ingredient string    `json:"ingredient"`
	Canonical  string    `json:"canonical"`
	AddedAt    time.Time `json:"addedAt,omitempty"`
}

// Shopping list item sources. A meal-plan item is an ingredient a planned
// recipe needs but the pantry lacks; checking one off stocks the pantry. A
// custom item is free text the user added (or scanned from a photo) that isn't
// a recipe ingredient at all; checking one off simply deletes it.
const (
	ShoppingSourceMealPlan = "meal_plan"
	ShoppingSourceCustom   = "custom"
)

// ShoppingListItem is one line on the shopping list. Source tells the client
// (and the check-off behaviour) which kind it is — see the constants above.
type ShoppingListItem struct {
	Name   string `json:"name"`
	Source string `json:"source"`
}
