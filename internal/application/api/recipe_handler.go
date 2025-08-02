package api

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"

	"github.com/google/uuid"
	"github.com/kieranajp/the-bluer-book/internal/application/api/middleware"
	"github.com/kieranajp/the-bluer-book/internal/domain/recipe"
	"github.com/kieranajp/the-bluer-book/internal/domain/recipe/service"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
)

type RecipeHandler struct {
	recipeService service.RecipeService
	logger        logger.Logger
}

func NewRecipeHandler(recipeService service.RecipeService, logger logger.Logger) *RecipeHandler {
	return &RecipeHandler{
		recipeService: recipeService,
		logger:        logger,
	}
}

// POST /api/recipes
func (h *RecipeHandler) CreateRecipe(w http.ResponseWriter, r *http.Request) {
	// Get validated recipe from middleware context
	rec := r.Context().Value(middleware.ValidatedRecipeKey).(recipe.Recipe)

	// Call service directly with validated data
	savedRecipe, err := h.recipeService.CreateRecipe(r.Context(), rec)
	if err != nil {
		h.logger.Error().Err(err).Msg("Failed to create recipe")
		h.writeErrorResponse(w, http.StatusInternalServerError, "creation_failed", "Failed to create recipe")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(savedRecipe)

	h.logger.Info().Str("recipe_id", savedRecipe.UUID.String()).Str("name", savedRecipe.Name).Msg("Recipe created via API")
}

// GET /api/recipes/{id}
func (h *RecipeHandler) GetRecipe(w http.ResponseWriter, r *http.Request) {
	// Extract ID from URL path
	path := strings.TrimPrefix(r.URL.Path, "/api/recipes/")
	if path == "" {
		h.writeErrorResponse(w, http.StatusBadRequest, "missing_id", "Recipe ID is required")
		return
	}

	recipeID, err := uuid.Parse(path)
	if err != nil {
		h.writeErrorResponse(w, http.StatusBadRequest, "invalid_id", "Invalid recipe ID format")
		return
	}

	recipe, err := h.recipeService.GetRecipe(r.Context(), recipeID)
	if err != nil {
		h.logger.Error().Err(err).Str("recipe_id", recipeID.String()).Msg("Failed to get recipe")
		h.writeErrorResponse(w, http.StatusInternalServerError, "retrieval_failed", "Failed to retrieve recipe")
		return
	}

	if recipe == nil {
		h.writeErrorResponse(w, http.StatusNotFound, "recipe_not_found", "Recipe not found")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(recipe)
}

// GET /api/recipes
func (h *RecipeHandler) ListRecipes(w http.ResponseWriter, r *http.Request) {
	// Parse query parameters
	limitStr := r.URL.Query().Get("limit")
	offsetStr := r.URL.Query().Get("offset")
	search := r.URL.Query().Get("search")

	// Set defaults
	limit := 20
	offset := 0

	if limitStr != "" {
		if l, err := strconv.Atoi(limitStr); err == nil && l > 0 && l <= 100 {
			limit = l
		}
	}

	if offsetStr != "" {
		if o, err := strconv.Atoi(offsetStr); err == nil && o >= 0 {
			offset = o
		}
	}

	recipes, total, err := h.recipeService.ListRecipes(r.Context(), limit, offset, search)
	if err != nil {
		h.logger.Error().Err(err).Msg("Failed to list recipes")
		h.writeErrorResponse(w, http.StatusInternalServerError, "listing_failed", "Failed to list recipes")
		return
	}

	response := map[string]interface{}{
		"recipes": recipes,
		"total":   total,
		"limit":   limit,
		"offset":  offset,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func (h *RecipeHandler) writeErrorResponse(w http.ResponseWriter, statusCode int, errorType, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"error": map[string]string{
			"code":    errorType,
			"message": message,
		},
	})
}
