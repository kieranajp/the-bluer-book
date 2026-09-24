package repository

import "testing"

func TestNormalizeUnitName(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"tablespoons", "tablespoons"},
		{"Tablespoons", "tablespoons"},
		{"TABLESPOONS", "tablespoons"},
		{"  cup  ", "cup"},
		{" TSP", "tsp"},
		{"", ""},
		{"   ", ""},
		{"mL", "ml"},
		{"  Grams ", "grams"},
	}

	for _, tt := range tests {
		got := normalizeUnitName(tt.input)
		if got != tt.want {
			t.Errorf("normalizeUnitName(%q) = %q, want %q", tt.input, got, tt.want)
		}
	}
}

func TestSplitIngredientQualifier(t *testing.T) {
	tests := []struct {
		input string
		base  string
		qual  string
	}{
		{"garlic cloves", "garlic", "cloves"},
		{"garlic clove", "garlic", "clove"},
		{"thyme sprigs", "thyme", "sprigs"},
		{"basil leaves", "basil leaves", ""},   // "leaf" is a form, not a count
		{"fresh garlic", "fresh garlic", ""},   // "garlic" is not a qualifier noun
		{"garlic", "garlic", ""},               // single word: never split
		{"cloves", "cloves", ""},               // single word: never split
		{"spring onions", "spring onions", ""}, // "onions" is a real ingredient name
		{"olive oil", "olive oil", ""},         // no qualifier present
		{"  garlic   cloves  ", "garlic", "cloves"},
		{"chicken breasts", "chicken breasts", ""}, // "breast" is not a count qualifier
		{"parsley sprigs", "parsley", "sprigs"},
		{"lime leaves", "lime leaves", ""},       // a real ingredient, not garlic-style
		{"beef ribs", "beef ribs", ""},           // "rib" is a form, not a count
		{"cinnamon stick", "cinnamon stick", ""}, // ditto "stick"
		{"garlic bulb", "garlic bulb", ""},       // "bulb" is a form, not a count
	}

	for _, tt := range tests {
		base, qual := splitIngredientQualifier(tt.input)
		if base != tt.base || qual != tt.qual {
			t.Errorf("splitIngredientQualifier(%q) = (%q, %q), want (%q, %q)",
				tt.input, base, qual, tt.base, tt.qual)
		}
	}
}
