package api

import (
	"encoding/json"
	"net/http"

	"github.com/kieranajp/the-bluer-book/internal/domain/recipe/service"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
)

type ImportHandler struct {
	importService service.ImportService
	logger        logger.Logger
}

type ErrorResponse struct {
	Error   string `json:"error"`
	Message string `json:"message"`
}

func NewImportHandler(importService service.ImportService, logger logger.Logger) *ImportHandler {
	return &ImportHandler{
		importService: importService,
		logger:        logger,
	}
}

func (h *ImportHandler) ImportRecipe(w http.ResponseWriter, r *http.Request) {
	// Set content type
	w.Header().Set("Content-Type", "application/json")

	// Decode the request body
	var req service.ImportRecipeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.logger.Error().Err(err).Msg("Failed to decode request body")
		h.writeErrorResponse(w, http.StatusBadRequest, "invalid_request", "Invalid JSON in request body")
		return
	}

	// Call the import service
	recipe, err := h.importService.ImportRecipe(r.Context(), req)
	if err != nil {
		h.logger.Error().Err(err).Msg("Failed to import recipe")

		// Determine if this is a client error or server error
		if isValidationError(err) {
			h.writeErrorResponse(w, http.StatusBadRequest, "validation_error", err.Error())
		} else {
			h.writeErrorResponse(w, http.StatusInternalServerError, "internal_error", "Failed to import recipe")
		}
		return
	}

	// Write the successful response
	w.WriteHeader(http.StatusCreated)
	if err := json.NewEncoder(w).Encode(recipe); err != nil {
		h.logger.Error().Err(err).Msg("Failed to encode response")
		h.writeErrorResponse(w, http.StatusInternalServerError, "encoding_error", "Failed to encode response")
		return
	}

	h.logger.Info().Str("recipe_id", recipe.UUID.String()).Msg("Recipe imported via API")
}

func (h *ImportHandler) writeErrorResponse(w http.ResponseWriter, statusCode int, errorType, message string) {
	w.WriteHeader(statusCode)
	errorResp := ErrorResponse{
		Error:   errorType,
		Message: message,
	}
	if err := json.NewEncoder(w).Encode(errorResp); err != nil {
		h.logger.Error().Err(err).Msg("Failed to encode error response")
	}
}

func isValidationError(err error) bool {
	// Check if the error message contains validation-related keywords
	errMsg := err.Error()
	return contains(errMsg, "validation failed") ||
		   contains(errMsg, "required") ||
		   contains(errMsg, "invalid")
}

func contains(s, substr string) bool {
	return len(s) >= len(substr) && (s == substr || (len(s) > len(substr) &&
		(s[:len(substr)] == substr || s[len(s)-len(substr):] == substr ||
		 indexOf(s, substr) != -1)))
}

func indexOf(s, substr string) int {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return i
		}
	}
	return -1
}
