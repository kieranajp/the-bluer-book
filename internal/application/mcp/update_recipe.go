package mcp

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"
	"github.com/mark3labs/mcp-go/mcp"
)

func (h *RecipeMCPHandler) UpdateRecipe(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
	// Parse recipe ID from MCP request
	recipeIDStr := req.GetString("recipe_id", "")
	if recipeIDStr == "" {
		return nil, fmt.Errorf("recipe_id is required")
	}

	recipeID, err := uuid.Parse(recipeIDStr)
	if err != nil {
		return nil, fmt.Errorf("invalid recipe ID format: %s", recipeIDStr)
	}

	// Get existing recipe to ensure it exists and to preserve unmodified fields
	existingRecipe, err := h.recipeService.GetRecipe(ctx, recipeID)
	if err != nil {
		h.logger.Error().Err(err).Str("recipe_id", recipeIDStr).Msg("Failed to get existing recipe for update via MCP")
		return nil, fmt.Errorf("failed to get existing recipe: %w", err)
	}

	if existingRecipe == nil {
		return nil, fmt.Errorf("recipe not found: %s", recipeIDStr)
	}

	// Start with existing recipe and update only provided fields
	updatedRecipe := *existingRecipe

	// Update basic fields if provided
	if name := req.GetString("name", ""); name != "" {
		updatedRecipe.Name = name
	}

	if description := req.GetString("description", ""); description != "" {
		updatedRecipe.Description = description
	}

	if cookTime := req.GetFloat("cook_time", -1); cookTime >= 0 {
		updatedRecipe.CookTime = int32(cookTime)
	}

	if prepTime := req.GetFloat("prep_time", -1); prepTime >= 0 {
		updatedRecipe.PrepTime = int32(prepTime)
	}

	if servings := req.GetFloat("servings", -1); servings >= 0 {
		updatedRecipe.Servings = int16(servings)
	}

	if url := req.GetString("url", ""); url != "" {
		updatedRecipe.Url = url
	}

	// Parse and update ingredients if provided
	args := req.GetArguments()
	if ingredientsData, ok := args["ingredients"].([]interface{}); ok && len(ingredientsData) > 0 {
		ingredients, err := h.parseIngredients(ingredientsData)
		if err != nil {
			return nil, fmt.Errorf("invalid ingredients: %w", err)
		}
		updatedRecipe.Ingredients = ingredients
	}

	// Parse and update steps if provided
	if stepsData, ok := args["steps"].([]interface{}); ok && len(stepsData) > 0 {
		steps, err := h.parseSteps(stepsData)
		if err != nil {
			return nil, fmt.Errorf("invalid steps: %w", err)
		}
		updatedRecipe.Steps = steps
	}

	// Parse and update labels if provided
	if labelsData, ok := args["labels"].([]interface{}); ok {
		labels, err := h.parseLabels(labelsData)
		if err != nil {
			return nil, fmt.Errorf("invalid labels: %w", err)
		}
		updatedRecipe.Labels = labels
	}

	// Call service layer to update the recipe
	savedRecipe, err := h.recipeService.UpdateRecipe(ctx, recipeID, updatedRecipe)
	if err != nil {
		h.logger.Error().Err(err).Str("recipe_id", recipeIDStr).Msg("Failed to update recipe via MCP")
		return nil, fmt.Errorf("failed to update recipe: %w", err)
	}

	if savedRecipe == nil {
		return nil, fmt.Errorf("recipe not found during update: %s", recipeIDStr)
	}

	h.logger.Info().Str("recipe_id", savedRecipe.UUID.String()).Str("name", savedRecipe.Name).Msg("Recipe updated via MCP")

	// Return the updated recipe in the same format as get_recipe
	responseJSON, _ := json.Marshal(savedRecipe)
	return mcp.NewToolResultText(string(responseJSON)), nil
}
