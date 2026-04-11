package mcp

import (
	"testing"

	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
)

func newTestHandler() *RecipeMCPHandler {
	return &RecipeMCPHandler{
		logger: logger.New(logger.LogLevelError),
	}
}

func TestParseIngredients_WithComponent(t *testing.T) {
	h := newTestHandler()

	data := []any{
		map[string]any{
			"name":      "soy sauce",
			"quantity":  3.0,
			"unit":      "tbsp",
			"component": "sauce",
		},
		map[string]any{
			"name":        "flour",
			"quantity":    200.0,
			"unit":        "grams",
			"preparation": "sifted",
			"component":   "batter",
		},
	}

	ingredients, err := h.parseIngredients(data)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if len(ingredients) != 2 {
		t.Fatalf("expected 2 ingredients, got %d", len(ingredients))
	}

	if ingredients[0].Component != "sauce" {
		t.Errorf("expected component %q, got %q", "sauce", ingredients[0].Component)
	}
	if ingredients[0].Ingredient.Name != "soy sauce" {
		t.Errorf("expected name %q, got %q", "soy sauce", ingredients[0].Ingredient.Name)
	}

	if ingredients[1].Component != "batter" {
		t.Errorf("expected component %q, got %q", "batter", ingredients[1].Component)
	}
	if ingredients[1].Preparation != "sifted" {
		t.Errorf("expected preparation %q, got %q", "sifted", ingredients[1].Preparation)
	}
}

func TestParseIngredients_WithoutComponent(t *testing.T) {
	h := newTestHandler()

	data := []any{
		map[string]any{
			"name":     "salt",
			"quantity": 1.0,
			"unit":     "tsp",
		},
	}

	ingredients, err := h.parseIngredients(data)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if len(ingredients) != 1 {
		t.Fatalf("expected 1 ingredient, got %d", len(ingredients))
	}

	if ingredients[0].Component != "" {
		t.Errorf("expected empty component, got %q", ingredients[0].Component)
	}
}

func TestParseIngredients_MixedComponents(t *testing.T) {
	h := newTestHandler()

	data := []any{
		map[string]any{
			"name":      "cauliflower",
			"quantity":  1.0,
			"unit":      "head",
			"component": "batter",
		},
		map[string]any{
			"name":     "sesame seeds",
			"quantity": 1.0,
			"unit":     "tbsp",
		},
		map[string]any{
			"name":      "rice vinegar",
			"quantity":  2.0,
			"unit":      "tbsp",
			"component": "sauce",
		},
	}

	ingredients, err := h.parseIngredients(data)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if len(ingredients) != 3 {
		t.Fatalf("expected 3 ingredients, got %d", len(ingredients))
	}

	if ingredients[0].Component != "batter" {
		t.Errorf("ingredient 0: expected component %q, got %q", "batter", ingredients[0].Component)
	}
	if ingredients[1].Component != "" {
		t.Errorf("ingredient 1: expected empty component, got %q", ingredients[1].Component)
	}
	if ingredients[2].Component != "sauce" {
		t.Errorf("ingredient 2: expected component %q, got %q", "sauce", ingredients[2].Component)
	}
}

func TestParseIngredients_MissingName(t *testing.T) {
	h := newTestHandler()

	data := []any{
		map[string]any{
			"quantity":  1.0,
			"unit":      "cup",
			"component": "sauce",
		},
	}

	_, err := h.parseIngredients(data)
	if err == nil {
		t.Fatal("expected error for missing name, got nil")
	}
}
