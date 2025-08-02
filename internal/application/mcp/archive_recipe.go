package mcp

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"
	"github.com/mark3labs/mcp-go/mcp"
)

func (h *RecipeMCPHandler) ArchiveRecipe(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
	// Parse recipe ID from MCP request
	recipeIDStr := req.GetString("recipe_id", "")
	if recipeIDStr == "" {
		return nil, fmt.Errorf("recipe_id is required")
	}

	recipeID, err := uuid.Parse(recipeIDStr)
	if err != nil {
		return nil, fmt.Errorf("invalid recipe ID format: %s", recipeIDStr)
	}

	// Get the recipe details before archiving for logging and response
	existingRecipe, err := h.recipeService.GetRecipe(ctx, recipeID)
	if err != nil {
		h.logger.Error().Err(err).Str("recipe_id", recipeIDStr).Msg("Failed to get recipe before archiving via MCP")
		return nil, fmt.Errorf("failed to get recipe: %w", err)
	}

	if existingRecipe == nil {
		return nil, fmt.Errorf("recipe not found: %s", recipeIDStr)
	}

	// Call service layer to archive the recipe
	err = h.recipeService.ArchiveRecipe(ctx, recipeID)
	if err != nil {
		h.logger.Error().Err(err).Str("recipe_id", recipeIDStr).Msg("Failed to archive recipe via MCP")
		return nil, fmt.Errorf("failed to archive recipe: %w", err)
	}

	h.logger.Info().Str("recipe_id", recipeIDStr).Str("name", existingRecipe.Name).Msg("Recipe archived via MCP")

	// Return success confirmation with archived recipe uuid
	response := map[string]interface{}{
		"success":     true,
		"message":     fmt.Sprintf("Successfully archived recipe: %s", existingRecipe.Name),
		"recipe_id":   recipeIDStr,
		"recipe_name": existingRecipe.Name,
		"archived":    true,
	}

	responseJSON, _ := json.Marshal(response)
	return mcp.NewToolResultText(string(responseJSON)), nil
}
