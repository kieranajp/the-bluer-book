package recipe

import (
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
)

// Duration is a wrapper for time.Duration that supports JSON unmarshalling from strings.
type Duration struct {
	time.Duration
}

func (d *Duration) UnmarshalJSON(b []byte) error {
	var s string
	if err := json.Unmarshal(b, &s); err != nil {
		return err
	}
	// Try Go duration format first
	dur, err := time.ParseDuration(s)
	if err == nil {
		d.Duration = dur
		return nil
	}
	// Try to parse common English formats (e.g., "45 minutes", "2 hours")
	s = strings.ToLower(strings.TrimSpace(s))
	if strings.Contains(s, "hour") {
		var hours int
		_, err := fmt.Sscanf(s, "%d hour", &hours)
		if err != nil {
			_, err = fmt.Sscanf(s, "%d hours", &hours)
		}
		if err == nil {
			d.Duration = time.Duration(hours) * time.Hour
			return nil
		}
	}
	if strings.Contains(s, "minute") {
		var minutes int
		_, err := fmt.Sscanf(s, "%d minute", &minutes)
		if err != nil {
			_, err = fmt.Sscanf(s, "%d minutes", &minutes)
		}
		if err == nil {
			d.Duration = time.Duration(minutes) * time.Minute
			return nil
		}
	}
	return fmt.Errorf("could not parse duration: %s", s)
}

// Recipe is the aggregate root for a recipe and its related data.
type Recipe struct {
	UUID        uuid.UUID          `json:"uuid,omitempty"`
	Name        string             `json:"name"`
	Description string             `json:"description"`
	CookTime    Duration           `json:"cookTime"`
	PrepTime    Duration           `json:"prepTime"`
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
