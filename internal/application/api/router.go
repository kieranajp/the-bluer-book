package api

import (
	"net/http"

	"github.com/prometheus/client_golang/prometheus/promhttp"

	"github.com/kieranajp/the-bluer-book/internal/application/api/middleware"
	"github.com/kieranajp/the-bluer-book/internal/application/chat"
	pantryservice "github.com/kieranajp/the-bluer-book/internal/domain/pantry/service"
	"github.com/kieranajp/the-bluer-book/internal/domain/recipe/service"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/ai"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/metrics"
)

func NewRouter(recipeService service.RecipeService, pantryService pantryservice.PantryService, scanner *ai.ShoppingListScanner, chatHandler *chat.Handler, photoHandler *PhotoHandler, logger logger.Logger) http.Handler {
	mux := http.NewServeMux()

	// Prometheus metrics endpoint
	mux.Handle("GET /metrics", promhttp.Handler())

	// Create handlers
	recipeHandler := NewRecipeHandler(recipeService, logger)
	pantryHandler := NewPantryHandler(pantryService, scanner, logger)
	validationMiddleware := middleware.NewValidationMiddleware(logger)

	mux.HandleFunc("GET /api/units", recipeHandler.ListUnits)
	mux.HandleFunc("GET /api/ingredients", recipeHandler.ListIngredients)

	mux.HandleFunc("GET /api/recipes", recipeHandler.ListRecipes)
	mux.HandleFunc("GET /api/labels", recipeHandler.ListLabels)
	mux.HandleFunc("GET /api/recipes/archived", recipeHandler.ListArchivedRecipes)
	mux.HandleFunc("GET /api/recipes/meal-plan", recipeHandler.ListMealPlanRecipes)
	mux.HandleFunc("GET /api/recipes/{id}", recipeHandler.GetRecipe)
	mux.HandleFunc("DELETE /api/recipes/{id}", recipeHandler.DeleteRecipe)
	mux.HandleFunc("POST /api/recipes/{id}/restore", recipeHandler.RestoreRecipe)

	// Meal planning routes
	mux.HandleFunc("POST /api/recipes/{id}/meal-plan", recipeHandler.AddToMealPlan)
	mux.HandleFunc("DELETE /api/recipes/{id}/meal-plan", recipeHandler.RemoveFromMealPlan)

	// Pantry routes
	mux.HandleFunc("GET /api/pantry", pantryHandler.ListPantry)
	mux.HandleFunc("PUT /api/pantry/{ingredient}", pantryHandler.AddToPantry)
	mux.HandleFunc("DELETE /api/pantry/{ingredient}", pantryHandler.RemoveFromPantry)

	// Shopping list: meal-plan shortfall plus free-text custom items.
	mux.HandleFunc("GET /api/shopping-list", pantryHandler.ShoppingList)
	mux.HandleFunc("POST /api/shopping-list", pantryHandler.AddCustomShoppingItem)
	mux.HandleFunc("POST /api/shopping-list/scan", pantryHandler.ScanShoppingList)
	mux.HandleFunc("DELETE /api/shopping-list/{name}", pantryHandler.RemoveCustomShoppingItem)

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

	// Photo upload
	if photoHandler != nil {
		mux.HandleFunc("POST /api/recipes/{id}/photo", photoHandler.UploadRecipePhoto)
	}

	// Chat endpoint
	mux.HandleFunc("POST /api/chat", chatHandler.HandleChat)

	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})

	return metrics.HTTPMetrics(middleware.AccessLog(logger, mux))
}
