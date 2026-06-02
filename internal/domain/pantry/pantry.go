package pantry

import "time"

// PantryItem records that the user currently has a given ingredient at home.
// Presence-only (v1): the ingredient is identified by its name, which is
// unique in the ingredients table.
type PantryItem struct {
	Ingredient string    `json:"ingredient"`
	AddedAt    time.Time `json:"addedAt,omitempty"`
}
