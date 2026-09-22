package mcp

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/mark3labs/mcp-go/mcp"
)

func (h *RecipeMCPHandler) ListIngredients(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
	ingredients, err := h.recipeService.ListIngredients(ctx)
	if err != nil {
		h.logger.Error().Err(err).Msg("Failed to list ingredients via MCP")
		return nil, fmt.Errorf("failed to list ingredients: %w", err)
	}

	response := map[string]any{
		"ingredients": ingredients,
		"total":       len(ingredients),
	}

	responseJSON, _ := json.Marshal(response)
	return mcp.NewToolResultText(string(responseJSON)), nil
}