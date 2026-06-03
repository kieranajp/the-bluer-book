package recipe

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
)

// Recipe is the aggregate root for a recipe and its related data.
type Recipe struct {
	UUID         uuid.UUID          `json:"uuid,omitempty"`
	Name         string             `json:"name"`
	Description  string             `json:"description"`
	CookTime     int32              `json:"cookTime"`
	PrepTime     int32              `json:"prepTime"`
	Servings     int16              `json:"servings"`
	MainPhoto    *Photo             `json:"mainPhoto"`
	Url          string             `json:"url"`
	CreatedAt    time.Time          `json:"createdAt,omitempty"`
	UpdatedAt    time.Time          `json:"updatedAt,omitempty"`
	IsInMealPlan bool               `json:"isInMealPlan"`
	Steps        []Step             `json:"steps"`
	Ingredients  []RecipeIngredient `json:"ingredients"`
	Labels       []Label            `json:"labels"`
	Photos       []Photo            `json:"photos"`
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
	Ingredient  Ingredient `json:"ingredient"`
	Unit        Unit       `json:"unit"`
	Quantity    float64    `json:"quantity"`
	Preparation string     `json:"preparation"`
	Component   string     `json:"component"`
}

type Label struct {
	Type      string    `json:"type"`
	Name      string    `json:"name"`
	CreatedAt time.Time `json:"createdAt,omitempty"`
	UpdatedAt time.Time `json:"updatedAt,omitempty"`
}

// LabelSummary is a label plus its usage count, returned by the labels listing endpoint.
type LabelSummary struct {
	Type string `json:"type"`
	Name string `json:"name"`
	Uses int    `json:"uses"`
}

// Photo is a value object representing a photo attached to a recipe or step.
type Photo struct {
	URL       string    `json:"url"`
	CreatedAt time.Time `json:"createdAt,omitempty"`
	UpdatedAt time.Time `json:"updatedAt,omitempty"`
}

func (r Recipe) MarshalJSON() ([]byte, error) {
	var mainPhoto *string
	if r.MainPhoto != nil && r.MainPhoto.URL != "" {
		mainPhoto = &r.MainPhoto.URL
	}
	return json.Marshal(&struct {
		UUID         uuid.UUID          `json:"uuid,omitempty"`
		Name         string             `json:"name"`
		Description  string             `json:"description"`
		CookTime     int32              `json:"cookTime"`
		PrepTime     int32              `json:"prepTime"`
		Servings     int16              `json:"servings"`
		MainPhoto    *string            `json:"mainPhoto"`
		Url          string             `json:"url"`
		CreatedAt    time.Time          `json:"createdAt,omitempty"`
		UpdatedAt    time.Time          `json:"updatedAt,omitempty"`
		IsInMealPlan bool               `json:"isInMealPlan"`
		Steps        []Step             `json:"steps"`
		Ingredients  []RecipeIngredient `json:"ingredients"`
		Labels       []Label            `json:"labels"`
		Photos       []Photo            `json:"photos"`
	}{
		UUID:         r.UUID,
		Name:         r.Name,
		Description:  r.Description,
		CookTime:     r.CookTime,
		PrepTime:     r.PrepTime,
		Servings:     r.Servings,
		MainPhoto:    mainPhoto,
		Url:          r.Url,
		CreatedAt:    r.CreatedAt,
		UpdatedAt:    r.UpdatedAt,
		IsInMealPlan: r.IsInMealPlan,
		Steps:        r.Steps,
		Ingredients:  r.Ingredients,
		Labels:       r.Labels,
		Photos:       r.Photos,
	})
}

// UnmarshalJSON mirrors MarshalJSON, which serialises mainPhoto as a bare URL
// string. Without this, a recipe round-tripped through the API (read, edited,
// saved) fails to decode because the default decoder expects mainPhoto to be a
// Photo object — the exact reason imported recipes (which carry a photo) could
// not be saved. We accept a string, a full Photo object, or null for safety.
func (r *Recipe) UnmarshalJSON(data []byte) error {
	type recipeAlias Recipe
	aux := &struct {
		MainPhoto json.RawMessage `json:"mainPhoto"`
		*recipeAlias
	}{
		recipeAlias: (*recipeAlias)(r),
	}
	if err := json.Unmarshal(data, aux); err != nil {
		return err
	}

	r.MainPhoto = nil
	if len(aux.MainPhoto) == 0 || string(aux.MainPhoto) == "null" {
		return nil
	}

	// Preferred shape: a bare URL string, matching MarshalJSON's output.
	var url string
	if err := json.Unmarshal(aux.MainPhoto, &url); err == nil {
		if url != "" {
			r.MainPhoto = &Photo{URL: url}
		}
		return nil
	}

	// Tolerate a full Photo object too.
	var photo Photo
	if err := json.Unmarshal(aux.MainPhoto, &photo); err != nil {
		return err
	}
	if photo.URL != "" {
		r.MainPhoto = &photo
	}
	return nil
}
