package api

import (
	"encoding/json"
	"io"
	"net/http"
	"strings"

	"github.com/kieranajp/the-bluer-book/internal/domain/pantry"
	"github.com/kieranajp/the-bluer-book/internal/domain/pantry/service"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/ai"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
)

type PantryHandler struct {
	pantryService service.PantryService
	scanner       *ai.ShoppingListScanner
	logger        logger.Logger
}

// NewPantryHandler wires the pantry/shopping-list endpoints. scanner may be nil
// when Gemini isn't configured, in which case the photo-scan endpoint reports
// that it's unavailable rather than failing.
func NewPantryHandler(pantryService service.PantryService, scanner *ai.ShoppingListScanner, logger logger.Logger) *PantryHandler {
	return &PantryHandler{
		pantryService: pantryService,
		scanner:       scanner,
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

// GET /api/shopping-list - Everything to buy: meal-plan ingredients not yet in
// the pantry, plus any free-text custom items the user added or scanned.
func (h *PantryHandler) ShoppingList(w http.ResponseWriter, r *http.Request) {
	items, err := h.pantryService.ShoppingList(r.Context())
	if err != nil {
		h.logger.Error().Err(err).Msg("Failed to build shopping list")
		h.writeErrorResponse(w, http.StatusInternalServerError, "shopping_list_failed", "Failed to build shopping list")
		return
	}

	if items == nil {
		items = []pantry.ShoppingListItem{}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]any{
		"items": items,
		"total": len(items),
	})
}

// POST /api/shopping-list - Add a free-text custom item, e.g. {"name": "washing-up liquid"}
func (h *PantryHandler) AddCustomShoppingItem(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Name string `json:"name"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		h.writeErrorResponse(w, http.StatusBadRequest, "invalid_request", "Invalid request body")
		return
	}
	if strings.TrimSpace(body.Name) == "" {
		h.writeErrorResponse(w, http.StatusBadRequest, "missing_name", "Item name is required")
		return
	}

	if err := h.pantryService.AddCustomShoppingItem(r.Context(), body.Name); err != nil {
		h.logger.Error().Err(err).Str("name", body.Name).Msg("Failed to add custom shopping list item")
		h.writeErrorResponse(w, http.StatusInternalServerError, "shopping_add_failed", "Failed to add item to shopping list")
		return
	}

	w.WriteHeader(http.StatusNoContent)
	h.logger.Info().Str("name", body.Name).Msg("Custom shopping list item added")
}

// DELETE /api/shopping-list/{name} - Remove a custom item from the shopping list
func (h *PantryHandler) RemoveCustomShoppingItem(w http.ResponseWriter, r *http.Request) {
	name := r.PathValue("name")
	if name == "" {
		h.writeErrorResponse(w, http.StatusBadRequest, "missing_name", "Item name is required")
		return
	}

	if err := h.pantryService.RemoveCustomShoppingItem(r.Context(), name); err != nil {
		h.logger.Error().Err(err).Str("name", name).Msg("Failed to remove custom shopping list item")
		h.writeErrorResponse(w, http.StatusInternalServerError, "shopping_remove_failed", "Failed to remove item from shopping list")
		return
	}

	w.WriteHeader(http.StatusNoContent)
	h.logger.Info().Str("name", name).Msg("Custom shopping list item removed")
}

// POST /api/shopping-list/scan - Upload a photo of a physical shopping list;
// Gemini parses the items and they're added as custom items. Returns the names
// that were added.
func (h *PantryHandler) ScanShoppingList(w http.ResponseWriter, r *http.Request) {
	if h.scanner == nil {
		h.writeErrorResponse(w, http.StatusServiceUnavailable, "scan_unavailable", "Photo scanning is not configured")
		return
	}

	r.Body = http.MaxBytesReader(w, r.Body, maxUploadSize)
	if err := r.ParseMultipartForm(maxUploadSize); err != nil {
		h.writeErrorResponse(w, http.StatusBadRequest, "file_too_large", "File too large (max 10MB)")
		return
	}

	file, header, err := r.FormFile("photo")
	if err != nil {
		h.writeErrorResponse(w, http.StatusBadRequest, "missing_photo", "Missing photo field")
		return
	}
	defer file.Close()

	data, err := io.ReadAll(file)
	if err != nil {
		h.writeErrorResponse(w, http.StatusInternalServerError, "read_failed", "Failed to read uploaded file")
		return
	}

	contentType := header.Header.Get("Content-Type")
	if contentType == "" {
		contentType = http.DetectContentType(data)
	}
	if !strings.HasPrefix(contentType, "image/") {
		h.writeErrorResponse(w, http.StatusBadRequest, "not_an_image", "File must be an image")
		return
	}

	names, err := h.scanner.Scan(r.Context(), data, contentType)
	if err != nil {
		h.logger.Error().Err(err).Msg("Failed to scan shopping list photo")
		h.writeErrorResponse(w, http.StatusBadGateway, "scan_failed", "Couldn't read the shopping list from that photo")
		return
	}

	added := make([]string, 0, len(names))
	for _, name := range names {
		if err := h.pantryService.AddCustomShoppingItem(r.Context(), name); err != nil {
			h.logger.Error().Err(err).Str("name", name).Msg("Failed to add scanned shopping list item")
			continue
		}
		added = append(added, name)
	}

	h.logger.Info().Int("added", len(added)).Msg("Scanned shopping list photo")
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]any{
		"added": added,
		"total": len(added),
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
