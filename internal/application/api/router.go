package api

import (
	"net/http"

	"github.com/kieranajp/the-bluer-book/internal/domain/recipe/service"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
)

func NewRouter(importService service.ImportService, logger logger.Logger) http.Handler {
	mux := http.NewServeMux()

	// Create handler
	handler := NewImportHandler(importService, logger)

	// Register routes
	mux.HandleFunc("POST /api/recipes/import", handler.ImportRecipe)

	return mux
}
