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

	// Read operations don't need validation middleware
	mux.HandleFunc("GET /api/recipes", recipeHandler.ListRecipes)
	mux.HandleFunc("GET /api/recipes/{id}", recipeHandler.GetRecipe)

	// Serve static files
	fs := http.FileServer(http.Dir("./static/"))
	mux.Handle("GET /", fs)

	return mux
}
