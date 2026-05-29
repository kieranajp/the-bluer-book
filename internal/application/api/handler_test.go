package api

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/google/uuid"
	"github.com/kieranajp/the-bluer-book/internal/domain/recipe"
	"github.com/rs/zerolog"
)

// --- Stubs ---

type noopLogger struct{}

func (n *noopLogger) Info() *zerolog.Event  { l := zerolog.Nop(); return l.Info() }
func (n *noopLogger) Debug() *zerolog.Event { l := zerolog.Nop(); return l.Debug() }
func (n *noopLogger) Warn() *zerolog.Event  { l := zerolog.Nop(); return l.Warn() }
func (n *noopLogger) Error() *zerolog.Event { l := zerolog.Nop(); return l.Error() }

type stubRecipeService struct {
	units       []recipe.Unit
	ingredients []recipe.Ingredient
	err         error
}

func (s *stubRecipeService) CreateRecipe(_ context.Context, _ recipe.Recipe) (*recipe.Recipe, error) {
	return nil, nil
}
func (s *stubRecipeService) GetRecipe(_ context.Context, _ uuid.UUID) (*recipe.Recipe, error) {
	return nil, nil
}
func (s *stubRecipeService) ListRecipes(_ context.Context, _, _ int, _ string, _ []string, _ string) ([]*recipe.Recipe, int, error) {
	return nil, 0, nil
}
func (s *stubRecipeService) UpdateRecipe(_ context.Context, _ uuid.UUID, _ recipe.Recipe) (*recipe.Recipe, error) {
	return nil, nil
}
func (s *stubRecipeService) ArchiveRecipe(_ context.Context, _ uuid.UUID) error { return nil }
func (s *stubRecipeService) RestoreRecipe(_ context.Context, _ uuid.UUID) (*recipe.Recipe, error) {
	return nil, nil
}
func (s *stubRecipeService) ListArchivedRecipes(_ context.Context, _, _ int) ([]*recipe.Recipe, int, error) {
	return nil, 0, nil
}
func (s *stubRecipeService) AddToMealPlan(_ context.Context, _ uuid.UUID) error    { return nil }
func (s *stubRecipeService) RemoveFromMealPlan(_ context.Context, _ uuid.UUID) error { return nil }
func (s *stubRecipeService) ListMealPlanRecipes(_ context.Context) ([]*recipe.Recipe, error) {
	return nil, nil
}

func (s *stubRecipeService) ListLabels(_ context.Context) ([]recipe.LabelSummary, error) {
	return nil, nil
}

func (s *stubRecipeService) ListUnits(_ context.Context) ([]recipe.Unit, error) {
	return s.units, s.err
}

func (s *stubRecipeService) ListIngredients(_ context.Context) ([]recipe.Ingredient, error) {
	return s.ingredients, s.err
}

// --- Tests ---

func TestListUnits_Success(t *testing.T) {
	svc := &stubRecipeService{
		units: []recipe.Unit{
			{Name: "cups", Abbreviation: "c"},
			{Name: "grams", Abbreviation: "g"},
			{Name: "tablespoons", Abbreviation: "tbsp"},
		},
	}
	h := NewRecipeHandler(svc, &noopLogger{})

	req := httptest.NewRequest(http.MethodGet, "/api/units", nil)
	rec := httptest.NewRecorder()
	h.ListUnits(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}

	var body struct {
		Units []struct {
			Name         string `json:"name"`
			Abbreviation string `json:"abbreviation"`
		} `json:"units"`
	}
	if err := json.NewDecoder(rec.Body).Decode(&body); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if len(body.Units) != 3 {
		t.Fatalf("expected 3 units, got %d", len(body.Units))
	}
	if body.Units[0].Name != "cups" {
		t.Errorf("expected first unit name %q, got %q", "cups", body.Units[0].Name)
	}
	if body.Units[0].Abbreviation != "c" {
		t.Errorf("expected first unit abbreviation %q, got %q", "c", body.Units[0].Abbreviation)
	}
}

func TestListUnits_Empty(t *testing.T) {
	svc := &stubRecipeService{units: []recipe.Unit{}}
	h := NewRecipeHandler(svc, &noopLogger{})

	req := httptest.NewRequest(http.MethodGet, "/api/units", nil)
	rec := httptest.NewRecorder()
	h.ListUnits(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}

	var body struct {
		Units []any `json:"units"`
	}
	if err := json.NewDecoder(rec.Body).Decode(&body); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if len(body.Units) != 0 {
		t.Errorf("expected 0 units, got %d", len(body.Units))
	}
}

func TestListUnits_ServiceError(t *testing.T) {
	svc := &stubRecipeService{err: errors.New("db down")}
	h := NewRecipeHandler(svc, &noopLogger{})

	req := httptest.NewRequest(http.MethodGet, "/api/units", nil)
	rec := httptest.NewRecorder()
	h.ListUnits(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("expected 500, got %d", rec.Code)
	}
}

func TestListIngredients_Success(t *testing.T) {
	svc := &stubRecipeService{
		ingredients: []recipe.Ingredient{
			{Name: "carrot"},
			{Name: "flour"},
			{Name: "salt"},
		},
	}
	h := NewRecipeHandler(svc, &noopLogger{})

	req := httptest.NewRequest(http.MethodGet, "/api/ingredients", nil)
	rec := httptest.NewRecorder()
	h.ListIngredients(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}

	var body struct {
		Ingredients []struct {
			Name string `json:"name"`
		} `json:"ingredients"`
	}
	if err := json.NewDecoder(rec.Body).Decode(&body); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if len(body.Ingredients) != 3 {
		t.Fatalf("expected 3 ingredients, got %d", len(body.Ingredients))
	}
	if body.Ingredients[0].Name != "carrot" {
		t.Errorf("expected first ingredient %q, got %q", "carrot", body.Ingredients[0].Name)
	}
}

func TestListIngredients_Empty(t *testing.T) {
	svc := &stubRecipeService{ingredients: []recipe.Ingredient{}}
	h := NewRecipeHandler(svc, &noopLogger{})

	req := httptest.NewRequest(http.MethodGet, "/api/ingredients", nil)
	rec := httptest.NewRecorder()
	h.ListIngredients(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}

	var body struct {
		Ingredients []any `json:"ingredients"`
	}
	if err := json.NewDecoder(rec.Body).Decode(&body); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if len(body.Ingredients) != 0 {
		t.Errorf("expected 0 ingredients, got %d", len(body.Ingredients))
	}
}

func TestListIngredients_ServiceError(t *testing.T) {
	svc := &stubRecipeService{err: errors.New("db down")}
	h := NewRecipeHandler(svc, &noopLogger{})

	req := httptest.NewRequest(http.MethodGet, "/api/ingredients", nil)
	rec := httptest.NewRecorder()
	h.ListIngredients(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("expected 500, got %d", rec.Code)
	}
}
