package metrics

import "testing"

func TestQueryName(t *testing.T) {
	tests := []struct {
		name  string
		query string
		want  string
	}{
		{
			name:  "sqlc header",
			query: "-- name: ListRecipes :many\nSELECT * FROM recipes",
			want:  "ListRecipes",
		},
		{
			name:  "exec kind",
			query: "-- name: AddToPantry :exec\nINSERT INTO pantry_items (ingredient_id) VALUES ($1)",
			want:  "AddToPantry",
		},
		{
			name:  "extra whitespace",
			query: "--   name:   CountRecipes   :one\nSELECT count(*) FROM recipes",
			want:  "CountRecipes",
		},
		{
			name:  "no header falls back",
			query: "SELECT 1",
			want:  "unknown",
		},
		{
			name:  "empty query falls back",
			query: "",
			want:  "unknown",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := queryName(tt.query); got != tt.want {
				t.Errorf("queryName() = %q, want %q", got, tt.want)
			}
		})
	}
}
