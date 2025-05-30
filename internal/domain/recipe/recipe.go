package recipe

import (
	"time"

	"github.com/google/uuid"
)

// Recipe is the aggregate root for a recipe and its related data.
type Recipe struct {
	UUID        uuid.UUID
	Name        string
	Description string
	CookTime    time.Duration
	PrepTime    time.Duration
	Servings    int16
	MainPhoto   *Photo // Main photo for the recipe, if any
	Url         string
	CreatedAt   time.Time
	UpdatedAt   time.Time
	Steps       []Step
	Ingredients []RecipeIngredient // Ingredients with quantity/unit for this recipe
	Labels      []Label
	Photos      []Photo // Other photos directly attached to the recipe
}

// Step is a value object representing a step in a recipe.
type Step struct {
	Order       int16
	Description string
	Photos      []Photo // Photos specific to this step
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

// Ingredient is a value object representing an ingredient.
type Ingredient struct {
	Name      string
	CreatedAt time.Time
	UpdatedAt time.Time
}

type Unit struct {
	Name         string
	Abbreviation string
	CreatedAt    time.Time
	UpdatedAt    time.Time
}

// RecipeIngredient ties an ingredient to a recipe with quantity and unit.
type RecipeIngredient struct {
	Ingredient Ingredient
	Unit       Unit
	Quantity   float64
}

type Label struct {
	Name      string
	Color     string
	CreatedAt time.Time
	UpdatedAt time.Time
}

// Photo is a value object representing a photo attached to a recipe or step.
type Photo struct {
	URL       string
	CreatedAt time.Time
	UpdatedAt time.Time
}
