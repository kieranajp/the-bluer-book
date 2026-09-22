package api

import (
	"encoding/json"
	"io"
	"net/http"
	"strings"

	"github.com/google/uuid"
	"github.com/kieranajp/the-bluer-book/internal/domain/recipe/service"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/upload"
)

type PhotoHandler struct {
	uploader      *upload.R2Uploader
	recipeService service.RecipeService
	logger        logger.Logger
}

func NewPhotoHandler(uploader *upload.R2Uploader, recipeService service.RecipeService, logger logger.Logger) *PhotoHandler {
	return &PhotoHandler{
		uploader:      uploader,
		recipeService: recipeService,
		logger:        logger,
	}
}

const maxUploadSize = 10 << 20 // 10 MB

func (h *PhotoHandler) UploadRecipePhoto(w http.ResponseWriter, r *http.Request) {
	pathParts := strings.Split(strings.TrimPrefix(r.URL.Path, "/api/recipes/"), "/")
	if len(pathParts) != 2 || pathParts[1] != "photo" {
		writeAPIError(w, http.StatusBadRequest, "invalid_path", "Not a recipe photo path")
		return
	}

	recipeID, err := uuid.Parse(pathParts[0])
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, "invalid_recipe_id", "Recipe id is not a uuid")
		return
	}

	r.Body = http.MaxBytesReader(w, r.Body, maxUploadSize)
	if err := r.ParseMultipartForm(maxUploadSize); err != nil {
		writeAPIError(w, http.StatusBadRequest, "photo_too_large", "Photo is larger than 10MB")
		return
	}

	file, header, err := r.FormFile("photo")
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, "photo_missing", "Request carries no photo field")
		return
	}
	defer file.Close()

	data, err := io.ReadAll(file)
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, "photo_unreadable", "Could not read the uploaded photo")
		return
	}

	contentType := header.Header.Get("Content-Type")
	if contentType == "" {
		contentType = http.DetectContentType(data)
	}
	if !strings.HasPrefix(contentType, "image/") {
		writeAPIError(w, http.StatusBadRequest, "photo_not_an_image", "Uploaded file is not an image")
		return
	}

	photoURL, err := h.uploader.UploadRecipePhoto(r.Context(), recipeID.String(), data, contentType, header.Filename)
	if err != nil {
		h.logger.Error().Err(err).Str("recipe_id", recipeID.String()).Msg("Failed to upload photo to R2")
		writeAPIError(w, http.StatusInternalServerError, "photo_not_stored", "Could not store the photo")
		return
	}

	if err := h.recipeService.SetMainPhoto(r.Context(), recipeID, photoURL); err != nil {
		h.logger.Error().Err(err).Str("recipe_id", recipeID.String()).Msg("Failed to save recipe photo")
		writeAPIError(w, http.StatusInternalServerError, "photo_not_saved", "Could not save the photo against the recipe")
		return
	}

	h.logger.Info().Str("recipe_id", recipeID.String()).Str("photo_url", photoURL).Msg("Recipe photo uploaded")
	writeJSON(w, http.StatusOK, map[string]any{"url": photoURL})
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

// writeAPIError writes the one error shape this API has, which is the only one
// the Flutter client reads a message out of.
func writeAPIError(w http.ResponseWriter, status int, code, message string) {
	writeJSON(w, status, map[string]any{
		"error": map[string]string{
			"code":    code,
			"message": message,
		},
	})
}
