package mcp

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"
	"github.com/mark3labs/mcp-go/mcp"
)

func (h *RecipeMCPHandler) AddToMealPlan(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
	recipeIDStr := req.GetString("recipe_id", "")
	if recipeIDStr == "" {
		return nil, fmt.Errorf("recipe_id is required")
	}

	recipeID, err := uuid.Parse(recipeIDStr)
	if err != nil {
		return nil, fmt.Errorf("invalid recipe ID format: %s", recipeIDStr)
	}

	existingRecipe, err := h.recipeService.GetRecipe(ctx, recipeID)
	if err != nil {
		h.logger.Error().Err(err).Str("recipe_id", recipeIDStr).Msg("Failed to get recipe before adding to meal plan via MCP")
		return nil, fmt.Errorf("failed to get recipe: %w", err)
	}

	if existingRecipe == nil {
		return nil, fmt.Errorf("recipe not found: %s", recipeIDStr)
	}

	err = h.recipeService.AddToMealPlan(ctx, recipeID)
	if err != nil {
		h.logger.Error().Err(err).Str("recipe_id", recipeIDStr).Msg("Failed to add recipe to meal plan via MCP")
		return nil, fmt.Errorf("failed to add recipe to meal plan: %w", err)
	}

	h.logger.Info().Str("recipe_id", recipeIDStr).Str("name", existingRecipe.Name).Msg("Recipe added to meal plan via MCP")

	response := map[string]any{
		"success":     true,
		"message":     fmt.Sprintf("Added '%s' to the meal plan", existingRecipe.Name),
		"recipe_id":   recipeIDStr,
		"recipe_name": existingRecipe.Name,
	}

	responseJSON, _ := json.Marshal(response)
	return mcp.NewToolResultText(string(responseJSON)), nil
}
