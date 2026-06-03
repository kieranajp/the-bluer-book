package recipe

import (
	"encoding/json"
	"testing"
)

func TestRecipeIngredientJSON_WithComponent(t *testing.T) {
	ri := RecipeIngredient{
		Ingredient:  Ingredient{Name: "soy sauce"},
		Unit:        Unit{Name: "tablespoons", Abbreviation: "tbsp"},
		Quantity:    2,
		Preparation: "mixed",
		Component:   "sauce",
	}

	data, err := json.Marshal(ri)
	if err != nil {
		t.Fatalf("failed to marshal: %v", err)
	}

	var parsed RecipeIngredient
	if err := json.Unmarshal(data, &parsed); err != nil {
		t.Fatalf("failed to unmarshal: %v", err)
	}

	if parsed.Component != "sauce" {
		t.Errorf("expected component %q, got %q", "sauce", parsed.Component)
	}
	if parsed.Preparation != "mixed" {
		t.Errorf("expected preparation %q, got %q", "mixed", parsed.Preparation)
	}
	if parsed.Ingredient.Name != "soy sauce" {
		t.Errorf("expected ingredient name %q, got %q", "soy sauce", parsed.Ingredient.Name)
	}
	if parsed.Quantity != 2 {
		t.Errorf("expected quantity %v, got %v", 2.0, parsed.Quantity)
	}
}

func TestRecipeIngredientJSON_WithoutComponent(t *testing.T) {
	ri := RecipeIngredient{
		Ingredient: Ingredient{Name: "salt"},
		Unit:       Unit{Name: "teaspoons", Abbreviation: "tsp"},
		Quantity:   1,
	}

	data, err := json.Marshal(ri)
	if err != nil {
		t.Fatalf("failed to marshal: %v", err)
	}

	var parsed RecipeIngredient
	if err := json.Unmarshal(data, &parsed); err != nil {
		t.Fatalf("failed to unmarshal: %v", err)
	}

	if parsed.Component != "" {
		t.Errorf("expected empty component, got %q", parsed.Component)
	}
}

func TestRecipeIngredientJSON_ComponentInPayload(t *testing.T) {
	// Simulates JSON arriving from the API with component set
	payload := `{
		"ingredient": {"name": "rice vinegar"},
		"unit": {"name": "tablespoons", "abbreviation": "tbsp"},
		"quantity": 3,
		"preparation": "warm",
		"component": "sauce"
	}`

	var ri RecipeIngredient
	if err := json.Unmarshal([]byte(payload), &ri); err != nil {
		t.Fatalf("failed to unmarshal: %v", err)
	}

	if ri.Ingredient.Name != "rice vinegar" {
		t.Errorf("expected ingredient name %q, got %q", "rice vinegar", ri.Ingredient.Name)
	}
	if ri.Component != "sauce" {
		t.Errorf("expected component %q, got %q", "sauce", ri.Component)
	}
	if ri.Preparation != "warm" {
		t.Errorf("expected preparation %q, got %q", "warm", ri.Preparation)
	}
}

func TestRecipeJSON_MixedComponents(t *testing.T) {
	// A recipe with ingredients across multiple components
	r := Recipe{
		Name: "Dongpo Cauliflower",
		Ingredients: []RecipeIngredient{
			{Ingredient: Ingredient{Name: "cauliflower"}, Quantity: 1, Unit: Unit{Name: "head"}, Component: "batter"},
			{Ingredient: Ingredient{Name: "flour"}, Quantity: 200, Unit: Unit{Name: "grams", Abbreviation: "g"}, Component: "batter"},
			{Ingredient: Ingredient{Name: "soy sauce"}, Quantity: 3, Unit: Unit{Name: "tablespoons", Abbreviation: "tbsp"}, Component: "sauce"},
			{Ingredient: Ingredient{Name: "sugar"}, Quantity: 2, Unit: Unit{Name: "tablespoons", Abbreviation: "tbsp"}, Component: "sauce"},
			{Ingredient: Ingredient{Name: "sesame seeds"}, Quantity: 1, Unit: Unit{Name: "tablespoons", Abbreviation: "tbsp"}},
		},
	}

	data, err := json.Marshal(r)
	if err != nil {
		t.Fatalf("failed to marshal recipe: %v", err)
	}

	var parsed Recipe
	if err := json.Unmarshal(data, &parsed); err != nil {
		t.Fatalf("failed to unmarshal recipe: %v", err)
	}

	if len(parsed.Ingredients) != 5 {
		t.Fatalf("expected 5 ingredients, got %d", len(parsed.Ingredients))
	}

	// Verify components are preserved
	components := map[string]int{}
	for _, ing := range parsed.Ingredients {
		components[ing.Component]++
	}
	if components["batter"] != 2 {
		t.Errorf("expected 2 batter ingredients, got %d", components["batter"])
	}
	if components["sauce"] != 2 {
		t.Errorf("expected 2 sauce ingredients, got %d", components["sauce"])
	}
	if components[""] != 1 {
		t.Errorf("expected 1 uncategorised ingredient, got %d", components[""])
	}
}

// TestRecipeMainPhotoRoundTrip guards against the asymmetry that previously
// broke saving any recipe with a photo: MarshalJSON emits mainPhoto as a URL
// string, so UnmarshalJSON must accept that same string back.
func TestRecipeMainPhotoRoundTrip(t *testing.T) {
	original := Recipe{
		Name:        "Imported recipe",
		Description: "has a photo",
		MainPhoto:   &Photo{URL: "https://example.com/photo.jpg"},
		Steps:       []Step{{Order: 1, Description: "do a thing"}},
	}

	data, err := json.Marshal(original)
	if err != nil {
		t.Fatalf("failed to marshal: %v", err)
	}

	var parsed Recipe
	if err := json.Unmarshal(data, &parsed); err != nil {
		t.Fatalf("failed to unmarshal round-tripped recipe: %v", err)
	}

	if parsed.MainPhoto == nil {
		t.Fatalf("expected MainPhoto to survive round-trip, got nil")
	}
	if parsed.MainPhoto.URL != original.MainPhoto.URL {
		t.Errorf("expected URL %q, got %q", original.MainPhoto.URL, parsed.MainPhoto.URL)
	}
}

func TestRecipeMainPhotoUnmarshalShapes(t *testing.T) {
	cases := map[string]struct {
		json    string
		wantURL string // "" means MainPhoto should be nil
	}{
		"string":       {`{"name":"r","mainPhoto":"https://x/p.jpg"}`, "https://x/p.jpg"},
		"empty string": {`{"name":"r","mainPhoto":""}`, ""},
		"null":         {`{"name":"r","mainPhoto":null}`, ""},
		"absent":       {`{"name":"r"}`, ""},
		"object":       {`{"name":"r","mainPhoto":{"url":"https://x/o.jpg"}}`, "https://x/o.jpg"},
	}

	for name, tc := range cases {
		t.Run(name, func(t *testing.T) {
			var parsed Recipe
			if err := json.Unmarshal([]byte(tc.json), &parsed); err != nil {
				t.Fatalf("unmarshal failed: %v", err)
			}
			if tc.wantURL == "" {
				if parsed.MainPhoto != nil {
					t.Errorf("expected nil MainPhoto, got %+v", parsed.MainPhoto)
				}
				return
			}
			if parsed.MainPhoto == nil || parsed.MainPhoto.URL != tc.wantURL {
				t.Errorf("expected URL %q, got %+v", tc.wantURL, parsed.MainPhoto)
			}
		})
	}
}
