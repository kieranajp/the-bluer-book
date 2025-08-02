package mcp

import (
	"github.com/kieranajp/the-bluer-book/internal/domain/recipe/service"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
	"github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"
)

type RecipeMCPHandler struct {
	recipeService service.RecipeService
	logger        logger.Logger
}

func NewRecipeMCPHandler(recipeService service.RecipeService, logger logger.Logger) *RecipeMCPHandler {
	return &RecipeMCPHandler{
		recipeService: recipeService,
		logger:        logger,
	}
}

func (h *RecipeMCPHandler) RegisterTools(s *server.MCPServer) {
	// Register create_recipe tool
	s.AddTool(
		mcp.NewTool("create_recipe",
			mcp.WithDescription("Create a new recipe with ingredients and steps"),
			mcp.WithString("name", mcp.Required(), mcp.Description("Recipe name")),
			mcp.WithString("description", mcp.Description("Recipe description")),
			mcp.WithArray("ingredients", mcp.Required(), mcp.Description("Array of ingredient objects with name, quantity, unit"),
				mcp.Items(map[string]any{
					"type": "object",
					"properties": map[string]any{
						"name":        map[string]any{"type": "string", "description": "Ingredient name"},
						"quantity":    map[string]any{"type": "number", "description": "Amount"},
						"unit":        map[string]any{"type": "string", "description": "Unit of measurement"},
						"preparation": map[string]any{"type": "string", "description": "Preparation notes"},
					},
					"required": []string{"name"},
				}),
			),
			mcp.WithArray("steps", mcp.Required(), mcp.Description("Array of step instructions in order"),
				mcp.WithStringItems(mcp.Description("Step instruction")),
			),
			mcp.WithNumber("cook_time", mcp.Description("Cooking time in minutes")),
			mcp.WithNumber("prep_time", mcp.Description("Prep time in minutes")),
			mcp.WithNumber("servings", mcp.Description("Number of servings")),
			mcp.WithString("url", mcp.Description("Source URL for the recipe")),
			mcp.WithArray("labels", mcp.Description("Array of label objects with name and color"),
				mcp.Items(map[string]any{
					"type": "object",
					"properties": map[string]any{
						"name":  map[string]any{"type": "string", "description": "Label name"},
						"color": map[string]any{"type": "string", "description": "Label color (hex or name)"},
					},
					"required": []string{"name"},
				}),
			),
		),
		h.CreateRecipe,
	)

	// Register search_recipes tool
	s.AddTool(
		mcp.NewTool("search_recipes",
			mcp.WithDescription("Search for recipes by name, description, or ingredients"),
			mcp.WithString("query", mcp.Required(), mcp.Description("Search term")),
			mcp.WithNumber("limit", mcp.DefaultNumber(5), mcp.Max(20), mcp.Description("Maximum number of results")),
			mcp.WithString("format", mcp.DefaultString("summary"), mcp.Description("Response format: summary or full")),
		),
		h.SearchRecipes,
	)

	// Register get_recipe tool
	s.AddTool(
		mcp.NewTool("get_recipe",
			mcp.WithDescription("Get a specific recipe by ID"),
			mcp.WithString("recipe_id", mcp.Required(), mcp.Description("UUID of the recipe")),
			mcp.WithString("section", mcp.DefaultString("full"), mcp.Description("Section to return: full, ingredients, steps, summary")),
		),
		h.GetRecipe,
	)
}
