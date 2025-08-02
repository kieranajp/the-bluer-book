package mcp

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/mark3labs/mcp-go/mcp"
)

func (h *RecipeMCPHandler) SearchRecipes(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
	query := req.GetString("query", "")
	limit := req.GetInt("limit", 5)
	format := req.GetString("format", "summary")

	// Call service layer directly
	recipes, total, err := h.recipeService.ListRecipes(ctx, limit, 0, query)
	if err != nil {
		h.logger.Error().Err(err).Msg("Failed to search recipes via MCP")
		return nil, fmt.Errorf("search failed: %w", err)
	}

	// Format response based on requested format
	var response map[string]interface{}
	if format == "summary" {
		summaries := make([]map[string]interface{}, len(recipes))
		for i, recipe := range recipes {
			summaries[i] = map[string]interface{}{
				"id":          recipe.UUID.String(),
				"name":        recipe.Name,
				"description": recipe.Description,
				"cook_time":   recipe.CookTime,
				"prep_time":   recipe.PrepTime,
				"servings":    recipe.Servings,
			}
		}
		response = map[string]interface{}{
			"recipes": summaries,
			"total":   total,
			"query":   query,
			"format":  "summary",
		}
	} else {
		response = map[string]interface{}{
			"recipes": recipes,
			"total":   total,
			"query":   query,
			"format":  "full",
		}
	}

	responseJSON, _ := json.Marshal(response)
	return mcp.NewToolResultText(string(responseJSON)), nil
}
