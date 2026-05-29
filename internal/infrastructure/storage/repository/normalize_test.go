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
