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

	mux.HandleFunc("GET /api/recipes", recipeHandler.ListRecipes)
	mux.HandleFunc("GET /api/recipes/archived", recipeHandler.ListArchivedRecipes)
	mux.HandleFunc("GET /api/recipes/{id}", recipeHandler.GetRecipe)
	mux.HandleFunc("DELETE /api/recipes/{id}", recipeHandler.DeleteRecipe)
	mux.HandleFunc("POST /api/recipes/{id}/restore", recipeHandler.RestoreRecipe)

	mux.Handle("POST /api/recipes",
		validationMiddleware.ValidateCreateRecipe(
			http.HandlerFunc(recipeHandler.CreateRecipe),
		),
	)

	mux.Handle("PUT /api/recipes/{id}",
		validationMiddleware.ValidateCreateRecipe(
			http.HandlerFunc(recipeHandler.UpdateRecipe),
		),
	)

	// Serve static files
	fs := http.FileServer(http.Dir("./static/"))
	mux.Handle("GET /", fs)

	return mux
}
