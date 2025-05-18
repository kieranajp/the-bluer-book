package recipe

import "time"

type Recipe struct {
	UUID        string
	Name        string
	Description string
	Timing      time.Duration
	ServingSize int16
	Steps       []Step
	Ingredients []RecipeIngredient
}

type Step struct {
	UUID        string
	RecipeID    string
	StepIndex   int16
	Description string
}

type Ingredient struct {
	UUID string
	Name string
}

type Unit struct {
	UUID         string
	Name         string
	Abbreviation string
}

type RecipeIngredient struct {
	RecipeID   string
	Ingredient Ingredient
	Unit       Unit
	Quantity   float64
}
