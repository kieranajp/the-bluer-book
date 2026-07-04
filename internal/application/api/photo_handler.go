package api

import (
	"database/sql"
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/storage/db"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/storage/repository"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/upload"
)

type PhotoHandler struct {
	uploader *upload.R2Uploader
	sqlDB    *sql.DB
	logger   logger.Logger
}

func NewPhotoHandler(uploader *upload.R2Uploader, sqlDB *sql.DB, logger logger.Logger) *PhotoHandler {
	return &PhotoHandler{
		uploader: uploader,
		sqlDB:    sqlDB,
		logger:   logger,
	}
}

const maxUploadSize = 10 << 20 // 10 MB

func (h *PhotoHandler) UploadRecipePhoto(w http.ResponseWriter, r *http.Request) {
	pathParts := strings.Split(strings.TrimPrefix(r.URL.Path, "/api/recipes/"), "/")
	if len(pathParts) != 2 || pathParts[1] != "photo" {
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": "invalid path"})
		return
	}

	recipeID, err := uuid.Parse(pathParts[0])
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": "invalid recipe ID"})
		return
	}

	r.Body = http.MaxBytesReader(w, r.Body, maxUploadSize)
	if err := r.ParseMultipartForm(maxUploadSize); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": "file too large (max 10MB)"})
		return
	}

	file, header, err := r.FormFile("photo")
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": "missing photo field"})
		return
	}
	defer file.Close()

	data, err := io.ReadAll(file)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]any{"error": "failed to read file"})
		return
	}

	contentType := header.Header.Get("Content-Type")
	if contentType == "" {
		contentType = http.DetectContentType(data)
	}
	if !strings.HasPrefix(contentType, "image/") {
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": "file must be an image"})
		return
	}

	photoURL, err := h.uploader.UploadRecipePhoto(r.Context(), recipeID.String(), data, contentType, header.Filename)
	if err != nil {
		h.logger.Error().Err(err).Str("recipe_id", recipeID.String()).Msg("Failed to upload photo to R2")
		writeJSON(w, http.StatusInternalServerError, map[string]any{"error": "failed to upload photo"})
		return
	}

	now := time.Now()
	photoUUID := uuid.New()

	err = repository.InHomeTx(r.Context(), h.sqlDB, func(q *db.Queries) error {
		if _, err := q.CreatePhoto(r.Context(), db.CreatePhotoParams{
			Uuid:       photoUUID,
			Url:        photoURL,
			EntityType: "recipe",
			EntityID:   recipeID,
			CreatedAt:  now,
			UpdatedAt:  now,
		}); err != nil {
			return err
		}
		return q.SetRecipeMainPhoto(r.Context(), db.SetRecipeMainPhotoParams{
			Uuid:        recipeID,
			MainPhotoID: uuid.NullUUID{UUID: photoUUID, Valid: true},
			UpdatedAt:   now,
		})
	})
	if err != nil {
		h.logger.Error().Err(err).Str("recipe_id", recipeID.String()).Msg("Failed to record uploaded photo")
		writeJSON(w, http.StatusInternalServerError, map[string]any{"error": "failed to save photo record"})
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
