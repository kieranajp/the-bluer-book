package api

import (
	"encoding/json"
	"errors"
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

// PUT /api/recipes/{id}
func (h *RecipeHandler) UpdateRecipe(w http.ResponseWriter, r *http.Request) {
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

	// Get validated recipe from middleware context
	rec := r.Context().Value(middleware.ValidatedRecipeKey).(recipe.Recipe)

	// Update the recipe
	updatedRecipe, err := h.recipeService.UpdateRecipe(r.Context(), recipeID, rec)
	if err != nil {
		if errors.Is(err, recipe.ErrRecipeNotFound) {
			h.writeErrorResponse(w, http.StatusNotFound, "recipe_not_found", "Recipe not found")
			return
		}
		h.logger.Error().Err(err).Str("recipe_id", recipeID.String()).Msg("Failed to update recipe")
		h.writeErrorResponse(w, http.StatusInternalServerError, "update_failed", "Failed to update recipe")
		return
	}

	if updatedRecipe == nil {
		h.writeErrorResponse(w, http.StatusNotFound, "recipe_not_found", "Recipe not found")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(updatedRecipe)

	h.logger.Info().Str("recipe_id", recipeID.String()).Str("name", updatedRecipe.Name).Msg("Recipe updated via API")
}

// DELETE /api/recipes/{id} - Soft delete (archive)
func (h *RecipeHandler) DeleteRecipe(w http.ResponseWriter, r *http.Request) {
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

	// Archive (soft delete) the recipe
	err = h.recipeService.ArchiveRecipe(r.Context(), recipeID)
	if err != nil {
		if errors.Is(err, recipe.ErrRecipeNotFound) {
			h.writeErrorResponse(w, http.StatusNotFound, "recipe_not_found", "Recipe not found")
			return
		}
		h.logger.Error().Err(err).Str("recipe_id", recipeID.String()).Msg("Failed to archive recipe")
		h.writeErrorResponse(w, http.StatusInternalServerError, "archive_failed", "Failed to archive recipe")
		return
	}

	// Return 204 No Content for successful archive
	w.WriteHeader(http.StatusNoContent)
	h.logger.Info().Str("recipe_id", recipeID.String()).Msg("Recipe archived via API")
}

// POST /api/recipes/{id}/restore - Restore archived recipe
func (h *RecipeHandler) RestoreRecipe(w http.ResponseWriter, r *http.Request) {
	// Extract ID from URL path
	pathParts := strings.Split(strings.TrimPrefix(r.URL.Path, "/api/recipes/"), "/")
	if len(pathParts) != 2 || pathParts[1] != "restore" {
		h.writeErrorResponse(w, http.StatusBadRequest, "invalid_path", "Invalid restore path")
		return
	}

	recipeID, err := uuid.Parse(pathParts[0])
	if err != nil {
		h.writeErrorResponse(w, http.StatusBadRequest, "invalid_id", "Invalid recipe ID format")
		return
	}

	restoredRecipe, err := h.recipeService.RestoreRecipe(r.Context(), recipeID)
	if err != nil {
		if errors.Is(err, recipe.ErrArchivedRecipeNotFound) {
			h.writeErrorResponse(w, http.StatusNotFound, "recipe_not_found", "Archived recipe not found")
			return
		}
		h.logger.Error().Err(err).Str("recipe_id", recipeID.String()).Msg("Failed to restore recipe")
		h.writeErrorResponse(w, http.StatusInternalServerError, "restore_failed", "Failed to restore recipe")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(restoredRecipe)

	h.logger.Info().Str("recipe_id", recipeID.String()).Msg("Recipe restored via API")
}

// GET /api/recipes/archived - List archived recipes
func (h *RecipeHandler) ListArchivedRecipes(w http.ResponseWriter, r *http.Request) {
	// Parse query parameters
	limitStr := r.URL.Query().Get("limit")
	offsetStr := r.URL.Query().Get("offset")

	limit := 10 // default
	offset := 0 // default

	if limitStr != "" {
		if l, err := strconv.Atoi(limitStr); err == nil && l > 0 {
			limit = l
		}
	}
	if offsetStr != "" {
		if o, err := strconv.Atoi(offsetStr); err == nil && o >= 0 {
			offset = o
		}
	}

	recipes, total, err := h.recipeService.ListArchivedRecipes(r.Context(), limit, offset)
	if err != nil {
		h.logger.Error().Err(err).Msg("Failed to list archived recipes")
		h.writeErrorResponse(w, http.StatusInternalServerError, "listing_failed", "Failed to list archived recipes")
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

// POST /api/recipes/{id}/meal-plan - Add recipe to meal plan
func (h *RecipeHandler) AddToMealPlan(w http.ResponseWriter, r *http.Request) {
	// Extract ID from URL path
	path := strings.TrimPrefix(r.URL.Path, "/api/recipes/")
	pathParts := strings.Split(path, "/")
	if len(pathParts) != 2 || pathParts[1] != "meal-plan" {
		h.writeErrorResponse(w, http.StatusBadRequest, "invalid_path", "Invalid meal plan path")
		return
	}

	recipeID, err := uuid.Parse(pathParts[0])
	if err != nil {
		h.writeErrorResponse(w, http.StatusBadRequest, "invalid_id", "Invalid recipe ID format")
		return
	}

	err = h.recipeService.AddToMealPlan(r.Context(), recipeID)
	if err != nil {
		h.logger.Error().Err(err).Str("recipe_id", recipeID.String()).Msg("Failed to add recipe to meal plan")
		h.writeErrorResponse(w, http.StatusInternalServerError, "meal_plan_add_failed", "Failed to add recipe to meal plan")
		return
	}

	w.WriteHeader(http.StatusNoContent)
	h.logger.Info().Str("recipe_id", recipeID.String()).Msg("Recipe added to meal plan")
}

// DELETE /api/recipes/{id}/meal-plan - Remove recipe from meal plan
func (h *RecipeHandler) RemoveFromMealPlan(w http.ResponseWriter, r *http.Request) {
	// Extract ID from URL path
	path := strings.TrimPrefix(r.URL.Path, "/api/recipes/")
	pathParts := strings.Split(path, "/")
	if len(pathParts) != 2 || pathParts[1] != "meal-plan" {
		h.writeErrorResponse(w, http.StatusBadRequest, "invalid_path", "Invalid meal plan path")
		return
	}

	recipeID, err := uuid.Parse(pathParts[0])
	if err != nil {
		h.writeErrorResponse(w, http.StatusBadRequest, "invalid_id", "Invalid recipe ID format")
		return
	}

	err = h.recipeService.RemoveFromMealPlan(r.Context(), recipeID)
	if err != nil {
		h.logger.Error().Err(err).Str("recipe_id", recipeID.String()).Msg("Failed to remove recipe from meal plan")
		h.writeErrorResponse(w, http.StatusInternalServerError, "meal_plan_remove_failed", "Failed to remove recipe from meal plan")
		return
	}

	w.WriteHeader(http.StatusNoContent)
	h.logger.Info().Str("recipe_id", recipeID.String()).Msg("Recipe removed from meal plan")
}
