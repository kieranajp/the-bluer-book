package mcp

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/mark3labs/mcp-go/mcp"
)

func (h *RecipeMCPHandler) ListMealPlan(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
	recipes, err := h.recipeService.ListMealPlanRecipes(ctx)
	if err != nil {
		h.logger.Error().Err(err).Msg("Failed to list meal plan recipes via MCP")
		return nil, fmt.Errorf("failed to list meal plan: %w", err)
	}

	summaries := make([]map[string]interface{}, len(recipes))
	for i, r := range recipes {
		summaries[i] = map[string]interface{}{
			"id":          r.UUID.String(),
			"name":        r.Name,
			"description": r.Description,
			"cook_time":   r.CookTime,
			"prep_time":   r.PrepTime,
			"servings":    r.Servings,
		}
	}

	response := map[string]interface{}{
		"recipes": summaries,
		"total":   len(recipes),
	}

	responseJSON, _ := json.Marshal(response)
	return mcp.NewToolResultText(string(responseJSON)), nil
}
