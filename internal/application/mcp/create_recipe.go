package mcp

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/kieranajp/the-bluer-book/internal/domain/recipe"
	"github.com/mark3labs/mcp-go/mcp"
)

func (h *RecipeMCPHandler) CreateRecipe(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
	// Parse parameters from MCP request
	name := req.GetString("name", "")
	description := req.GetString("description", "")
	cookTime := req.GetFloat("cook_time", 0)
	prepTime := req.GetFloat("prep_time", 0)
	servings := req.GetFloat("servings", 0)
	url := req.GetString("url", "")

	// Validate required fields
	if name == "" {
		return nil, fmt.Errorf("recipe name is required")
	}

	// Parse ingredients array
	args := req.GetArguments()
	ingredientsData, ok := args["ingredients"].([]interface{})
	if !ok || len(ingredientsData) == 0 {
		return nil, fmt.Errorf("at least one ingredient is required")
	}

	ingredients, err := h.parseIngredients(ingredientsData)
	if err != nil {
		return nil, fmt.Errorf("invalid ingredients: %w", err)
	}

	// Parse steps array
	stepsData, ok := args["steps"].([]interface{})
	if !ok || len(stepsData) == 0 {
		return nil, fmt.Errorf("at least one step is required")
	}

	steps, err := h.parseSteps(stepsData)
	if err != nil {
		return nil, fmt.Errorf("invalid steps: %w", err)
	}

	// Parse labels array
	labelsData, _ := args["labels"].([]interface{})
	labels, err := h.parseLabels(labelsData)
	if err != nil {
		return nil, fmt.Errorf("invalid labels: %w", err)
	}

	// Create recipe domain object
	rec := recipe.Recipe{
		Name:        name,
		Description: description,
		CookTime:    int32(cookTime),
		PrepTime:    int32(prepTime),
		Servings:    int16(servings),
		Url:         url,
		Steps:       steps,
		Ingredients: ingredients,
		Labels:      labels,
	}

	// Call service layer directly (same as HTTP handler)
	savedRecipe, err := h.recipeService.CreateRecipe(ctx, rec)
	if err != nil {
		h.logger.Error().Err(err).Msg("Failed to create recipe via MCP")
		return nil, fmt.Errorf("failed to create recipe: %w", err)
	}

	h.logger.Info().Str("recipe_id", savedRecipe.UUID.String()).Str("name", savedRecipe.Name).Msg("Recipe created via MCP")

	// Format response for LLM
	response := map[string]interface{}{
		"success":   true,
		"recipe_id": savedRecipe.UUID.String(),
		"name":      savedRecipe.Name,
		"message":   fmt.Sprintf("Recipe '%s' created successfully", savedRecipe.Name),
		"recipe":    savedRecipe,
	}

	responseJSON, _ := json.Marshal(response)
	return mcp.NewToolResultText(string(responseJSON)), nil
}

// Helper functions for parsing MCP arrays into domain objects
func (h *RecipeMCPHandler) parseIngredients(data []interface{}) ([]recipe.RecipeIngredient, error) {
	ingredients := make([]recipe.RecipeIngredient, 0, len(data))

	for i, item := range data {
		ingredientMap, ok := item.(map[string]interface{})
		if !ok {
			return nil, fmt.Errorf("ingredient %d must be an object", i)
		}

		name, ok := ingredientMap["name"].(string)
		if !ok || name == "" {
			return nil, fmt.Errorf("ingredient %d must have a name", i)
		}

		quantity, _ := ingredientMap["quantity"].(float64)
		unit, _ := ingredientMap["unit"].(string)
		preparation, _ := ingredientMap["preparation"].(string)

		ingredients = append(ingredients, recipe.RecipeIngredient{
			Ingredient: recipe.Ingredient{
				Name: name,
			},
			Unit: recipe.Unit{
				Name: unit,
			},
			Quantity:    quantity,
			Preparation: preparation,
		})
	}

	return ingredients, nil
}

func (h *RecipeMCPHandler) parseSteps(data []interface{}) ([]recipe.Step, error) {
	steps := make([]recipe.Step, 0, len(data))

	for i, item := range data {
		var description string

		// Handle both string and object formats
		switch v := item.(type) {
		case string:
			description = v
		case map[string]interface{}:
			desc, ok := v["description"].(string)
			if !ok {
				return nil, fmt.Errorf("step %d must have a description", i)
			}
			description = desc
		default:
			return nil, fmt.Errorf("step %d must be a string or object with description", i)
		}

		if description == "" {
			return nil, fmt.Errorf("step %d cannot be empty", i)
		}

		steps = append(steps, recipe.Step{
			Order:       int16(i + 1),
			Description: description,
		})
	}

	return steps, nil
}

func (h *RecipeMCPHandler) parseLabels(data []interface{}) ([]recipe.Label, error) {
	if len(data) == 0 {
		return []recipe.Label{}, nil
	}

	labels := make([]recipe.Label, 0, len(data))

	for i, item := range data {
		labelMap, ok := item.(map[string]interface{})
		if !ok {
			return nil, fmt.Errorf("label %d must be an object", i)
		}

		name, ok := labelMap["name"].(string)
		if !ok || name == "" {
			return nil, fmt.Errorf("label %d must have a name", i)
		}

		color, _ := labelMap["color"].(string)
		if color == "" {
			color = "#3498db" // Default blue color
		}

		labels = append(labels, recipe.Label{
			Name:  name,
			Color: color,
		})
	}

	return labels, nil
}
