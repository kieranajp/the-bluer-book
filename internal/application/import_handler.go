package application

import (
	"context"

	"github.com/kieranajp/the-bluer-book/internal/domain/recipe/service"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/storage/repository"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/trello"
)

type ImportHandler struct {
	loader     *trello.TrelloLoader
	normaliser service.Normaliser
	repo       repository.RecipeRepository
	logger     logger.Logger
}

func NewImportHandler(loader *trello.TrelloLoader, normaliser service.Normaliser, repo repository.RecipeRepository, logger logger.Logger) *ImportHandler {
	return &ImportHandler{
		loader:     loader,
		normaliser: normaliser,
		repo:       repo,
		logger:     logger,
	}
}

func (h *ImportHandler) RunImport(ctx context.Context) error {
	h.logger.Info().Msg("Loading Trello cards")
	cards, err := h.loader.LoadAllCards()
	if err != nil {
		h.logger.Error().Err(err).Msg("Failed to load Trello cards")
		return err
	}

	for _, card := range cards {
		h.logger.Info().Str("name", card.Name).Msg("Normalising card")
		err := h.normaliser.NormaliseRecipe(ctx, card)
		if err != nil {
			h.logger.Error().Str("name", card.Name).Err(err).Msg("Failed to normalise card")
			continue
		}
	}
	return nil
}
