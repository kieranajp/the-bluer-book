package recipe

import (
	"time"

	"github.com/google/uuid"
)

// Recipe is the aggregate root for a recipe and its related data.
type Recipe struct {
	UUID        uuid.UUID          `json:"uuid,omitempty"`
	Name        string             `json:"name"`
	Description string             `json:"description"`
	CookTime    int32              `json:"cookTime"`
	PrepTime    int32              `json:"prepTime"`
	Servings    int16              `json:"servings"`
	MainPhoto   *Photo             `json:"mainPhoto"`
	Url         string             `json:"url"`
	CreatedAt   time.Time          `json:"createdAt,omitempty"`
	UpdatedAt   time.Time          `json:"updatedAt,omitempty"`
	Steps       []Step             `json:"steps"`
	Ingredients []RecipeIngredient `json:"ingredients"`
	Labels      []Label            `json:"labels"`
	Photos      []Photo            `json:"photos"`
}

// Step is a value object representing a step in a recipe.
type Step struct {
	Order       int16     `json:"order"`
	Description string    `json:"description"`
	Photos      []Photo   `json:"photos"`
	CreatedAt   time.Time `json:"createdAt,omitempty"`
	UpdatedAt   time.Time `json:"updatedAt,omitempty"`
}

// Ingredient is a value object representing an ingredient.
type Ingredient struct {
	Name      string    `json:"name"`
	CreatedAt time.Time `json:"createdAt,omitempty"`
	UpdatedAt time.Time `json:"updatedAt,omitempty"`
}

type Unit struct {
	Name         string    `json:"name"`
	Abbreviation string    `json:"abbreviation"`
	CreatedAt    time.Time `json:"createdAt,omitempty"`
	UpdatedAt    time.Time `json:"updatedAt,omitempty"`
}

// RecipeIngredient ties an ingredient to a recipe with quantity and unit.
type RecipeIngredient struct {
	Ingredient Ingredient `json:"ingredient"`
	Unit       Unit       `json:"unit"`
	Quantity   float64    `json:"quantity"`
}

type Label struct {
	Name      string    `json:"name"`
	Color     string    `json:"color"`
	CreatedAt time.Time `json:"createdAt,omitempty"`
	UpdatedAt time.Time `json:"updatedAt,omitempty"`
}

// Photo is a value object representing a photo attached to a recipe or step.
type Photo struct {
	URL       string    `json:"url"`
	CreatedAt time.Time `json:"createdAt,omitempty"`
	UpdatedAt time.Time `json:"updatedAt,omitempty"`
}
