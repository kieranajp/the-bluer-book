package api

import (
	"net/http"

	"github.com/prometheus/client_golang/prometheus/promhttp"

	"github.com/kieranajp/the-bluer-book/internal/application/api/middleware"
	"github.com/kieranajp/the-bluer-book/internal/application/chat"
	"github.com/kieranajp/the-bluer-book/internal/domain/recipe/service"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/metrics"
)

func NewRouter(recipeService service.RecipeService, chatHandler *chat.Handler, logger logger.Logger) http.Handler {
	mux := http.NewServeMux()

	// Prometheus metrics endpoint
	mux.Handle("GET /metrics", promhttp.Handler())

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

	// Chat endpoint
	mux.HandleFunc("POST /api/chat", chatHandler.HandleChat)

	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})

	return metrics.HTTPMetrics(mux)
}
