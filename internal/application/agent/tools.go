package agent

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/kieranajp/the-bluer-book/internal/domain/recipe/service"
	"google.golang.org/adk/tool"
	"google.golang.org/adk/tool/functiontool"
)

type SearchRecipesInput struct {
	Query  string   `json:"query"`
	Limit  int      `json:"limit,omitempty"`
	Labels []string `json:"labels,omitempty"`
}

type RecipeSummary struct {
	ID          string   `json:"id"`
	Name        string   `json:"name"`
	Description string   `json:"description,omitempty"`
	PrepTime    int      `json:"prepTime,omitempty"`
	CookTime    int      `json:"cookTime,omitempty"`
	Servings    int      `json:"servings,omitempty"`
	Labels      []string `json:"labels,omitempty"`
}

type SearchRecipesOutput struct {
	Recipes []RecipeSummary `json:"recipes"`
	Total   int             `json:"total"`
}

type GetRecipeInput struct {
	RecipeID string `json:"recipeId"`
}

type IngredientDetail struct {
	Name        string  `json:"name"`
	Quantity    float64 `json:"quantity,omitempty"`
	Unit        string  `json:"unit,omitempty"`
	Preparation string  `json:"preparation,omitempty"`
}

type GetRecipeOutput struct {
	ID          string             `json:"id"`
	Name        string             `json:"name"`
	Description string             `json:"description,omitempty"`
	PrepTime    int                `json:"prepTime,omitempty"`
	CookTime    int                `json:"cookTime,omitempty"`
	Servings    int                `json:"servings,omitempty"`
	Ingredients []IngredientDetail `json:"ingredients"`
	Steps       []string           `json:"steps"`
	Labels      []string           `json:"labels,omitempty"`
	URL         string             `json:"url,omitempty"`
}

func NewSearchRecipesTool(recipeService service.RecipeService) (tool.Tool, error) {
	handler := func(ctx tool.Context, input SearchRecipesInput) (SearchRecipesOutput, error) {
		limit := input.Limit
		if limit == 0 {
			limit = 5
		}
		if limit > 20 {
			limit = 20
		}

		recipes, total, err := recipeService.ListRecipes(context.Background(), limit, 0, input.Query, input.Labels)
		if err != nil {
			return SearchRecipesOutput{}, fmt.Errorf("failed to search recipes: %w", err)
		}

		summaries := make([]RecipeSummary, len(recipes))
		for i, r := range recipes {
			labels := make([]string, len(r.Labels))
			for j, l := range r.Labels {
				labels[j] = l.Name
			}
			summaries[i] = RecipeSummary{
				ID:          r.UUID.String(),
				Name:        r.Name,
				Description: r.Description,
				PrepTime:    int(r.PrepTime),
				CookTime:    int(r.CookTime),
				Servings:    int(r.Servings),
				Labels:      labels,
			}
		}

		return SearchRecipesOutput{
			Recipes: summaries,
			Total:   total,
		}, nil
	}

	return functiontool.New(functiontool.Config{
		Name:        "search_recipes",
		Description: "Search for recipes by name, description, ingredients, or labels. Returns a list of matching recipes.",
	}, handler)
}

func NewGetRecipeTool(recipeService service.RecipeService) (tool.Tool, error) {
	handler := func(ctx tool.Context, input GetRecipeInput) (GetRecipeOutput, error) {
		recipeID, err := uuid.Parse(input.RecipeID)
		if err != nil {
			return GetRecipeOutput{}, fmt.Errorf("invalid recipe ID: %w", err)
		}

		r, err := recipeService.GetRecipe(context.Background(), recipeID)
		if err != nil {
			return GetRecipeOutput{}, fmt.Errorf("failed to get recipe: %w", err)
		}
		if r == nil {
			return GetRecipeOutput{}, fmt.Errorf("recipe not found")
		}

		ingredients := make([]IngredientDetail, len(r.Ingredients))
		for i, ing := range r.Ingredients {
			ingredients[i] = IngredientDetail{
				Name:        ing.Ingredient.Name,
				Quantity:    ing.Quantity,
				Unit:        ing.Unit.Name,
				Preparation: ing.Preparation,
			}
		}

		labels := make([]string, len(r.Labels))
		for i, l := range r.Labels {
			labels[i] = l.Name
		}

		steps := make([]string, len(r.Steps))
		for i, s := range r.Steps {
			steps[i] = s.Description
		}

		return GetRecipeOutput{
			ID:          r.UUID.String(),
			Name:        r.Name,
			Description: r.Description,
			PrepTime:    int(r.PrepTime),
			CookTime:    int(r.CookTime),
			Servings:    int(r.Servings),
			Ingredients: ingredients,
			Steps:       steps,
			Labels:      labels,
			URL:         r.Url,
		}, nil
	}

	return functiontool.New(functiontool.Config{
		Name:        "get_recipe",
		Description: "Get detailed information about a specific recipe by its ID, including full ingredients and cooking steps.",
	}, handler)
}
