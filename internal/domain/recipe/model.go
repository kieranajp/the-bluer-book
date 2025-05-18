package domain

import "time"

type Recipe struct {
	UUID        string
	Name        string
	Description string
	Timing      time.Duration
	ServingSize int16
	CreatedAt   time.Time
	UpdatedAt   time.Time
	Steps       []Step
	Ingredients []RecipeIngredient
}

type Step struct {
	UUID        string
	RecipeID    string
	StepIndex   int16
	Description string
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

type Ingredient struct {
	UUID      string
	Name      string
	CreatedAt time.Time
	UpdatedAt time.Time
}

type Unit struct {
	UUID         string
	Name         string
	Abbreviation string
	CreatedAt    time.Time
	UpdatedAt    time.Time
}

type RecipeIngredient struct {
	RecipeID   string
	Ingredient Ingredient
	Unit       Unit
	Quantity   float64
	CreatedAt  time.Time
	UpdatedAt  time.Time
}
