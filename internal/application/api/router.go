package api

import (
	"net/http"
	"path/filepath"
	"strings"

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
	mux.HandleFunc("GET /api/recipes/meal-plan", recipeHandler.ListMealPlanRecipes)
	mux.HandleFunc("GET /api/recipes/{id}", recipeHandler.GetRecipe)
	mux.HandleFunc("DELETE /api/recipes/{id}", recipeHandler.DeleteRecipe)
	mux.HandleFunc("POST /api/recipes/{id}/restore", recipeHandler.RestoreRecipe)

	// Meal planning routes
	mux.HandleFunc("POST /api/recipes/{id}/meal-plan", recipeHandler.AddToMealPlan)
	mux.HandleFunc("DELETE /api/recipes/{id}/meal-plan", recipeHandler.RemoveFromMealPlan)

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

	// SPA static + fallback handler
	staticDir := http.Dir("./static")
	fileServer := http.FileServer(staticDir)

	mux.Handle("GET /", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// If root, serve normally (will serve index.html by default)
		if r.URL.Path == "/" || r.URL.Path == "" {
			fileServer.ServeHTTP(w, r)
			return
		}

		// Prevent directory traversal
		cleanPath := filepath.Clean(r.URL.Path)
		// Basic heuristic: if path contains a dot, treat as static asset attempt
		if strings.Contains(filepath.Base(cleanPath), ".") {
			fileServer.ServeHTTP(w, r)
			return
		}

		// Attempt to open (in case it's an actual static folder/file without extension)
		f, err := staticDir.Open(strings.TrimPrefix(cleanPath, "/"))
		if err == nil {
			stat, statErr := f.Stat()
			_ = f.Close()
			if statErr == nil && !stat.IsDir() {
				// Serve existing file
				fileServer.ServeHTTP(w, r)
				return
			}
		}

		// Fallback: serve index.html for client-side route
		http.ServeFile(w, r, "./static/index.html")
	}))

	return mux
}
