package middleware

import (
	"context"
	"encoding/json"
	"net/http"

	"github.com/kieranajp/the-bluer-book/internal/domain/recipe"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
)

type contextKey string

const ValidatedRecipeKey contextKey = "validatedRecipe"

type ValidationMiddleware struct {
	logger logger.Logger
}

func NewValidationMiddleware(logger logger.Logger) *ValidationMiddleware {
	return &ValidationMiddleware{logger: logger}
}

// ValidateCreateRecipe validates recipe creation requests
func (m *ValidationMiddleware) ValidateCreateRecipe(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var rec recipe.Recipe
		if err := json.NewDecoder(r.Body).Decode(&rec); err != nil {
			m.logger.Error().Err(err).Msg("JSON decode error")
			m.writeValidationError(w, "invalid_json", "Invalid JSON format")
			return
		}

		// Validate required fields
		if rec.Name == "" {
			m.writeValidationError(w, "missing_name", "Recipe name is required")
			return
		}

		if len(rec.Steps) == 0 {
			m.writeValidationError(w, "missing_steps", "At least one step is required")
			return
		}

		if len(rec.Ingredients) == 0 {
			m.writeValidationError(w, "missing_ingredients", "At least one ingredient is required")
			return
		}

		// Validate steps have order and description
		for i, step := range rec.Steps {
			if step.Order <= 0 {
				m.writeValidationError(w, "invalid_step_order", "Step order must be greater than 0")
				return
			}
			if step.Description == "" {
				m.writeValidationError(w, "missing_step_description", "Step description is required")
				return
			}
			// Update step order to match index + 1 if not properly ordered
			rec.Steps[i].Order = int16(i + 1)
		}

		// Validate ingredients have required fields
		for _, ingredient := range rec.Ingredients {
			if ingredient.Ingredient.Name == "" {
				m.writeValidationError(w, "missing_ingredient_name", "Ingredient name is required")
				return
			}
			if ingredient.Quantity <= 0 {
				m.writeValidationError(w, "invalid_quantity", "Ingredient quantity must be greater than 0")
				return
			}
			if ingredient.Unit.Name == "" {
				m.writeValidationError(w, "missing_unit", "Ingredient unit is required")
				return
			}
		}

		// Store validated recipe in context for handler to use
		ctx := context.WithValue(r.Context(), ValidatedRecipeKey, rec)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func (m *ValidationMiddleware) writeValidationError(w http.ResponseWriter, code, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusBadRequest)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"error": map[string]string{
			"code":    code,
			"message": message,
		},
	})
}
