package middleware

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/kieranajp/the-bluer-book/internal/domain/recipe"
	"github.com/rs/zerolog"
)

type noopLogger struct{}

func (n *noopLogger) Info() *zerolog.Event  { l := zerolog.Nop(); return l.Info() }
func (n *noopLogger) Debug() *zerolog.Event { l := zerolog.Nop(); return l.Debug() }
func (n *noopLogger) Warn() *zerolog.Event  { l := zerolog.Nop(); return l.Warn() }
func (n *noopLogger) Error() *zerolog.Event { l := zerolog.Nop(); return l.Error() }

func okHandler(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusOK) }

func postRecipe(t *testing.T, r recipe.Recipe) *httptest.ResponseRecorder {
	t.Helper()
	body, err := json.Marshal(r)
	if err != nil {
		t.Fatalf("failed to marshal recipe: %v", err)
	}
	req := httptest.NewRequest(http.MethodPut, "/api/recipes/test", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	m := NewValidationMiddleware(&noopLogger{})
	m.ValidateCreateRecipe(http.HandlerFunc(okHandler)).ServeHTTP(rec, req)
	return rec
}

func validRecipe() recipe.Recipe {
	return recipe.Recipe{
		Name: "Mac and Cheese",
		Steps: []recipe.Step{
			{Order: 1, Description: "Boil pasta"},
		},
		Ingredients: []recipe.RecipeIngredient{
			{
				Ingredient: recipe.Ingredient{Name: "macaroni"},
				Unit:       recipe.Unit{Name: "g"},
				Quantity:   500,
			},
		},
	}
}

func TestValidation_ValidRecipe(t *testing.T) {
	rec := postRecipe(t, validRecipe())
	if rec.Code != http.StatusOK {
		t.Errorf("expected 200, got %d: %s", rec.Code, rec.Body.String())
	}
}

func TestValidation_MissingName(t *testing.T) {
	r := validRecipe()
	r.Name = ""
	rec := postRecipe(t, r)
	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", rec.Code)
	}
	assertErrorCode(t, rec, "missing_name")
}

func TestValidation_MissingSteps(t *testing.T) {
	r := validRecipe()
	r.Steps = nil
	rec := postRecipe(t, r)
	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", rec.Code)
	}
	assertErrorCode(t, rec, "missing_steps")
}

func TestValidation_MissingIngredients(t *testing.T) {
	r := validRecipe()
	r.Ingredients = nil
	rec := postRecipe(t, r)
	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", rec.Code)
	}
	assertErrorCode(t, rec, "missing_ingredients")
}

// Zero quantity with a unit (e.g. "a pinch of salt") must be allowed.
func TestValidation_ZeroQuantityWithUnit(t *testing.T) {
	r := validRecipe()
	r.Ingredients = append(r.Ingredients, recipe.RecipeIngredient{
		Ingredient: recipe.Ingredient{Name: "salt"},
		Unit:       recipe.Unit{Name: "pinch"},
		Quantity:   0,
	})
	rec := postRecipe(t, r)
	if rec.Code != http.StatusOK {
		t.Errorf("expected 200 for zero-quantity ingredient with unit, got %d: %s", rec.Code, rec.Body.String())
	}
}

// Zero quantity without a unit (e.g. "salt, to taste") must also be allowed.
func TestValidation_ZeroQuantityWithoutUnit(t *testing.T) {
	r := validRecipe()
	r.Ingredients = append(r.Ingredients, recipe.RecipeIngredient{
		Ingredient: recipe.Ingredient{Name: "salt and pepper"},
		Quantity:   0,
	})
	rec := postRecipe(t, r)
	if rec.Code != http.StatusOK {
		t.Errorf("expected 200 for unit-less ingredient, got %d: %s", rec.Code, rec.Body.String())
	}
}

// Negative quantity is never valid.
func TestValidation_NegativeQuantity(t *testing.T) {
	r := validRecipe()
	r.Ingredients = append(r.Ingredients, recipe.RecipeIngredient{
		Ingredient: recipe.Ingredient{Name: "butter"},
		Unit:       recipe.Unit{Name: "g"},
		Quantity:   -10,
	})
	rec := postRecipe(t, r)
	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected 400 for negative quantity, got %d", rec.Code)
	}
	assertErrorCode(t, rec, "invalid_quantity")
}

func assertErrorCode(t *testing.T, rec *httptest.ResponseRecorder, want string) {
	t.Helper()
	var body struct {
		Error struct {
			Code string `json:"code"`
		} `json:"error"`
	}
	if err := json.NewDecoder(rec.Body).Decode(&body); err != nil {
		t.Fatalf("failed to decode error response: %v", err)
	}
	if body.Error.Code != want {
		t.Errorf("expected error code %q, got %q", want, body.Error.Code)
	}
}
