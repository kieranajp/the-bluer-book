package service

import (
	"context"

	"github.com/kieranajp/the-bluer-book/internal/infrastructure/llm"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/storage/repository"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/trello"
)

type Normaliser interface {
	NormaliseRecipe(ctx context.Context, card trello.Card) error
}

type NormalisationService struct {
	llm    llm.LLMClient
	logger logger.Logger
	repo   repository.RecipeRepository
}

func NewNormalisationService(llm llm.LLMClient, logger logger.Logger, repo repository.RecipeRepository) *NormalisationService {
	return &NormalisationService{llm: llm, logger: logger, repo: repo}
}

func (s *NormalisationService) NormaliseRecipe(ctx context.Context, card trello.Card) error {
	recipe, err := s.llm.NormaliseRecipe(ctx, card)
	if err != nil {
		s.logger.Error().Err(err).Msg("Failed to normalise recipe")
		return err
	}
	_, err = s.repo.SaveRecipe(ctx, recipe)
	if err != nil {
		s.logger.Error().Err(err).Msg("Failed to save recipe")
		return err
	}
	return nil
}
