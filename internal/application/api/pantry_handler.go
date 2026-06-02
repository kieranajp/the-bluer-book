package api

import (
	"encoding/json"
	"net/http"

	"github.com/kieranajp/the-bluer-book/internal/domain/pantry/service"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
)

type PantryHandler struct {
	pantryService service.PantryService
	logger        logger.Logger
}

func NewPantryHandler(pantryService service.PantryService, logger logger.Logger) *PantryHandler {
	return &PantryHandler{
		pantryService: pantryService,
		logger:        logger,
	}
}

// ingredientFromPath reads the {ingredient} path parameter (the ingredient
// name, URL-encoded by the client). It writes an error response and returns
// ok=false when missing, so callers can simply `return` on !ok.
func (h *PantryHandler) ingredientFromPath(w http.ResponseWriter, r *http.Request) (string, bool) {
	name := r.PathValue("ingredient")
	if name == "" {
		h.writeErrorResponse(w, http.StatusBadRequest, "missing_ingredient", "Ingredient name is required")
		return "", false
	}
	return name, true
}

func (h *PantryHandler) writeErrorResponse(w http.ResponseWriter, statusCode int, errorType, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)
	json.NewEncoder(w).Encode(map[string]any{
		"error": map[string]string{
			"code":    errorType,
			"message": message,
		},
	})
}

// GET /api/pantry - List everything currently in the pantry
func (h *PantryHandler) ListPantry(w http.ResponseWriter, r *http.Request) {
	items, err := h.pantryService.ListPantry(r.Context())
	if err != nil {
		h.logger.Error().Err(err).Msg("Failed to list pantry")
		h.writeErrorResponse(w, http.StatusInternalServerError, "listing_failed", "Failed to list pantry")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]any{
		"items": items,
		"total": len(items),
	})
}

// GET /api/shopping-list - Ingredients needed for the meal plan but not yet in the pantry
func (h *PantryHandler) ShoppingList(w http.ResponseWriter, r *http.Request) {
	items, err := h.pantryService.ShoppingList(r.Context())
	if err != nil {
		h.logger.Error().Err(err).Msg("Failed to build shopping list")
		h.writeErrorResponse(w, http.StatusInternalServerError, "shopping_list_failed", "Failed to build shopping list")
		return
	}

	if items == nil {
		items = []string{}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]any{
		"items": items,
		"total": len(items),
	})
}

// PUT /api/pantry/{ingredient} - Mark an ingredient as in the pantry (idempotent)
func (h *PantryHandler) AddToPantry(w http.ResponseWriter, r *http.Request) {
	ingredient, ok := h.ingredientFromPath(w, r)
	if !ok {
		return
	}

	if err := h.pantryService.AddToPantry(r.Context(), ingredient); err != nil {
		h.logger.Error().Err(err).Str("ingredient", ingredient).Msg("Failed to add ingredient to pantry")
		h.writeErrorResponse(w, http.StatusInternalServerError, "pantry_add_failed", "Failed to add ingredient to pantry")
		return
	}

	w.WriteHeader(http.StatusNoContent)
	h.logger.Info().Str("ingredient", ingredient).Msg("Ingredient added to pantry")
}

// DELETE /api/pantry/{ingredient} - Remove an ingredient from the pantry
func (h *PantryHandler) RemoveFromPantry(w http.ResponseWriter, r *http.Request) {
	ingredient, ok := h.ingredientFromPath(w, r)
	if !ok {
		return
	}

	if err := h.pantryService.RemoveFromPantry(r.Context(), ingredient); err != nil {
		h.logger.Error().Err(err).Str("ingredient", ingredient).Msg("Failed to remove ingredient from pantry")
		h.writeErrorResponse(w, http.StatusInternalServerError, "pantry_remove_failed", "Failed to remove ingredient from pantry")
		return
	}

	w.WriteHeader(http.StatusNoContent)
	h.logger.Info().Str("ingredient", ingredient).Msg("Ingredient removed from pantry")
}
