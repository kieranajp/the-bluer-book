package api

import (
	"net/http"

	"github.com/prometheus/client_golang/prometheus/promhttp"

	"github.com/kieranajp/the-bluer-book/internal/application/api/middleware"
	"github.com/kieranajp/the-bluer-book/internal/application/chat"
	pantryservice "github.com/kieranajp/the-bluer-book/internal/domain/pantry/service"
	"github.com/kieranajp/the-bluer-book/internal/domain/recipe/service"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/ai"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/auth"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/metrics"
)

func NewRouter(recipeService service.RecipeService, pantryService pantryservice.PantryService, scanner *ai.ShoppingListScanner, chatHandler *chat.Handler, photoHandler *PhotoHandler, resolver auth.UserResolver, logger logger.Logger) http.Handler {
	mux := http.NewServeMux()

	// Prometheus metrics endpoint
	mux.Handle("GET /metrics", promhttp.Handler())

	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})

	// Create handlers
	recipeHandler := NewRecipeHandler(recipeService, logger)
	pantryHandler := NewPantryHandler(pantryService, scanner, logger)
	validationMiddleware := middleware.NewValidationMiddleware(logger)

	apiMux := http.NewServeMux()

	apiMux.HandleFunc("GET /api/units", recipeHandler.ListUnits)
	apiMux.HandleFunc("GET /api/ingredients", recipeHandler.ListIngredients)

	apiMux.HandleFunc("GET /api/recipes", recipeHandler.ListRecipes)
	apiMux.HandleFunc("GET /api/labels", recipeHandler.ListLabels)
	apiMux.HandleFunc("GET /api/recipes/archived", recipeHandler.ListArchivedRecipes)
	apiMux.HandleFunc("GET /api/recipes/meal-plan", recipeHandler.ListMealPlanRecipes)
	apiMux.HandleFunc("GET /api/recipes/{id}", recipeHandler.GetRecipe)
	apiMux.HandleFunc("DELETE /api/recipes/{id}", recipeHandler.DeleteRecipe)
	apiMux.HandleFunc("POST /api/recipes/{id}/restore", recipeHandler.RestoreRecipe)

	// Meal planning routes
	apiMux.HandleFunc("POST /api/recipes/{id}/meal-plan", recipeHandler.AddToMealPlan)
	apiMux.HandleFunc("DELETE /api/recipes/{id}/meal-plan", recipeHandler.RemoveFromMealPlan)

	// Pantry routes
	apiMux.HandleFunc("GET /api/pantry", pantryHandler.ListPantry)
	apiMux.HandleFunc("PUT /api/pantry/{ingredient}", pantryHandler.AddToPantry)
	apiMux.HandleFunc("DELETE /api/pantry/{ingredient}", pantryHandler.RemoveFromPantry)

	// Shopping list: meal-plan shortfall plus free-text custom items.
	apiMux.HandleFunc("GET /api/shopping-list", pantryHandler.ShoppingList)
	apiMux.HandleFunc("POST /api/shopping-list", pantryHandler.AddCustomShoppingItem)
	apiMux.HandleFunc("POST /api/shopping-list/scan", pantryHandler.ScanShoppingList)
	apiMux.HandleFunc("DELETE /api/shopping-list/{name}", pantryHandler.RemoveCustomShoppingItem)

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

	// Photo upload
	if photoHandler != nil {
		apiMux.HandleFunc("POST /api/recipes/{id}/photo", photoHandler.UploadRecipePhoto)
	}

	// Chat endpoint
	apiMux.HandleFunc("POST /api/chat", chatHandler.HandleChat)

	// Everything under /api acts on somebody's home, so the whole subtree hangs
	// off one nested mux behind the identity middleware. /health and /metrics
	// stay on the outer mux, where no caller is needed.
	mux.Handle("/api/", auth.Middleware(resolver, logger)(apiMux))

	return metrics.HTTPMetrics(middleware.AccessLog(logger, mux))
}
