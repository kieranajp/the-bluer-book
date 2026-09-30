package mcp

import (
	"github.com/kieranajp/the-bluer-book/internal/domain/recipe"
)

func labelTypeNames() []string {
	names := make([]string, len(recipe.LabelTypes))
	for i, t := range recipe.LabelTypes {
		names[i] = string(t)
	}
	return names
}

func ingredientItemSchema() map[string]any {
	return map[string]any{
		"type": "object",
		"properties": map[string]any{
			"name":        map[string]any{"type": "string", "description": "Ingredient name"},
			"quantity":    map[string]any{"type": "number", "description": "Amount"},
			"unit":        map[string]any{"type": "string", "description": "Unit of measurement"},
			"preparation": map[string]any{"type": "string", "description": "Preparation notes"},
			"component":   map[string]any{"type": "string", "description": "Component this ingredient belongs to, e.g. 'sauce', 'batter', 'filling'"},
		},
		"required": []string{"name"},
	}
}

func labelItemSchema(nameDescription string) map[string]any {
	return map[string]any{
		"type": "object",
		"properties": map[string]any{
			"type": map[string]any{"type": "string", "enum": labelTypeNames(), "description": "Label type"},
			"name": map[string]any{"type": "string", "description": nameDescription},
		},
		"required": []string{"type", "name"},
	}
}
