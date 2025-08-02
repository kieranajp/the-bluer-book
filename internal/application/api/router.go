package api

import (
	"net/http"

	"github.com/kieranajp/the-bluer-book/internal/application/api/middleware"
	"github.com/kieranajp/the-bluer-book/internal/domain/recipe/service"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
)

func NewRouter(recipeService service.RecipeService, logger logger.Logger) http.Handler {
	mux := http.NewServeMux()

	// Create handlers
	recipeHandler := NewRecipeHandler(recipeService, logger)
	validationMiddleware := middleware.NewValidationMiddleware(logger)

	// Register CRUD routes
	// Apply validation middleware only to routes that need it
	mux.Handle("POST /api/recipes",
		validationMiddleware.ValidateCreateRecipe(
			http.HandlerFunc(recipeHandler.CreateRecipe),
		),
	)

	// PUT requires validation middleware for the recipe data
	mux.Handle("PUT /api/recipes/{id}",
		validationMiddleware.ValidateCreateRecipe(
			http.HandlerFunc(recipeHandler.UpdateRecipe),
		),
	)

	// Read operations don't need validation middleware
	mux.HandleFunc("GET /api/recipes", recipeHandler.ListRecipes)
	mux.HandleFunc("GET /api/recipes/{id}", recipeHandler.GetRecipe)

	// Delete operation (soft delete) doesn't need validation middleware
	mux.HandleFunc("DELETE /api/recipes/{id}", recipeHandler.DeleteRecipe)

	// Admin operations for archived recipes (optional)
	mux.HandleFunc("POST /api/recipes/{id}/restore", recipeHandler.RestoreRecipe)
	mux.HandleFunc("GET /api/admin/recipes/archived", recipeHandler.ListArchivedRecipes)

	// Serve static files
	fs := http.FileServer(http.Dir("./static/"))
	mux.Handle("GET /", fs)

	return mux
}
