package mcp

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"
	"github.com/mark3labs/mcp-go/mcp"
)

func (h *RecipeMCPHandler) GetRecipe(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
	recipeIDStr := req.GetString("recipe_id", "")
	section := req.GetString("section", "full")

	if recipeIDStr == "" {
		return nil, fmt.Errorf("recipe_id is required")
	}

	recipeID, err := uuid.Parse(recipeIDStr)
	if err != nil {
		return nil, fmt.Errorf("invalid recipe ID format: %s", recipeIDStr)
	}

	// Call service layer directly
	recipe, err := h.recipeService.GetRecipe(ctx, recipeID)
	if err != nil {
		h.logger.Error().Err(err).Str("recipe_id", recipeIDStr).Msg("Failed to get recipe via MCP")
		return nil, fmt.Errorf("failed to get recipe: %w", err)
	}

	if recipe == nil {
		return nil, fmt.Errorf("recipe not found: %s", recipeIDStr)
	}

	// Format response based on requested section
	var response interface{}
	switch section {
	case "ingredients":
		response = map[string]interface{}{
			"recipe_id":   recipe.UUID.String(),
			"name":        recipe.Name,
			"ingredients": recipe.Ingredients,
		}
	case "steps":
		response = map[string]interface{}{
			"recipe_id": recipe.UUID.String(),
			"name":      recipe.Name,
			"steps":     recipe.Steps,
		}
	case "summary":
		response = map[string]interface{}{
			"recipe_id":   recipe.UUID.String(),
			"name":        recipe.Name,
			"description": recipe.Description,
			"cook_time":   recipe.CookTime,
			"prep_time":   recipe.PrepTime,
			"servings":    recipe.Servings,
		}
	default: // "full"
		response = recipe
	}

	responseJSON, _ := json.Marshal(response)
	return mcp.NewToolResultText(string(responseJSON)), nil
}
