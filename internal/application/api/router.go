package api

import (
	"net/http"

	"github.com/prometheus/client_golang/prometheus/promhttp"

	"github.com/kieranajp/the-bluer-book/internal/application/api/middleware"
	"github.com/kieranajp/the-bluer-book/internal/application/chat"
	"github.com/kieranajp/the-bluer-book/internal/domain/recipe/service"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/auth"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/metrics"
)

func NewRouter(recipeService service.RecipeService, chatHandler *chat.Handler, photoHandler *PhotoHandler, resolver auth.UserResolver, logger logger.Logger) http.Handler {
	mux := http.NewServeMux()

	// Health/metrics are not authenticated and not workspace-scoped.
	mux.Handle("GET /metrics", promhttp.Handler())
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})

	// Everything under /api/* requires an authenticated identity. The edge
	// (Oathkeeper) is what actually verifies the token; the middleware here
	// just trusts the X-User header on already-authenticated paths and maps
	// it to (user, active home) in context.
	apiMux := http.NewServeMux()

	recipeHandler := NewRecipeHandler(recipeService, logger)
	validationMiddleware := middleware.NewValidationMiddleware(logger)

	apiMux.HandleFunc("GET /api/units", recipeHandler.ListUnits)
	apiMux.HandleFunc("GET /api/ingredients", recipeHandler.ListIngredients)

	apiMux.HandleFunc("GET /api/recipes", recipeHandler.ListRecipes)
	apiMux.HandleFunc("GET /api/labels", recipeHandler.ListLabels)
	apiMux.HandleFunc("GET /api/recipes/archived", recipeHandler.ListArchivedRecipes)
	apiMux.HandleFunc("GET /api/recipes/meal-plan", recipeHandler.ListMealPlanRecipes)
	apiMux.HandleFunc("GET /api/recipes/{id}", recipeHandler.GetRecipe)
	apiMux.HandleFunc("DELETE /api/recipes/{id}", recipeHandler.DeleteRecipe)
	apiMux.HandleFunc("POST /api/recipes/{id}/restore", recipeHandler.RestoreRecipe)

	apiMux.HandleFunc("POST /api/recipes/{id}/meal-plan", recipeHandler.AddToMealPlan)
	apiMux.HandleFunc("DELETE /api/recipes/{id}/meal-plan", recipeHandler.RemoveFromMealPlan)

	apiMux.Handle("POST /api/recipes",
		validationMiddleware.ValidateCreateRecipe(
			http.HandlerFunc(recipeHandler.CreateRecipe),
		),
	)

	apiMux.Handle("PUT /api/recipes/{id}",
		validationMiddleware.ValidateCreateRecipe(
			http.HandlerFunc(recipeHandler.UpdateRecipe),
		),
	)

	if photoHandler != nil {
		apiMux.HandleFunc("POST /api/recipes/{id}/photo", photoHandler.UploadRecipePhoto)
	}

	apiMux.HandleFunc("POST /api/chat", chatHandler.HandleChat)

	authedAPI := auth.Middleware(resolver, logger)(apiMux)
	mux.Handle("/api/", authedAPI)

	return metrics.HTTPMetrics(middleware.AccessLog(logger, mux))
}
