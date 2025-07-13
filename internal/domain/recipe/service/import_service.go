package service

import (
	"context"
	"fmt"

	"github.com/kieranajp/the-bluer-book/internal/domain/recipe"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/storage/repository"
)

type ImportService interface {
	ImportRecipe(ctx context.Context, req ImportRecipeRequest) (*recipe.Recipe, error)
}

type ImportRecipeRequest struct {
	Name        string                       `json:"name"`
	Description string                       `json:"description"`
	CookTime    int32                        `json:"cookTime"`
	PrepTime    int32                        `json:"prepTime"`
	Servings    int16                        `json:"servings"`
	URL         string                       `json:"url"`
	Steps       []ImportStepRequest          `json:"steps"`
	Ingredients []ImportRecipeIngredient     `json:"ingredients"`
	Labels      []string                     `json:"labels"`
}

type ImportStepRequest struct {
	Order       int16  `json:"order"`
	Description string `json:"description"`
}

type ImportRecipeIngredient struct {
	Name         string  `json:"name"`
	Quantity     float64 `json:"quantity"`
	Unit         string  `json:"unit"`
	Preparation  string  `json:"preparation"`
}

type importService struct {
	normalizer Normaliser
	repo       repository.RecipeRepository
	logger     logger.Logger
}

func NewImportService(normalizer Normaliser, repo repository.RecipeRepository, logger logger.Logger) ImportService {
	return &importService{
		normalizer: normalizer,
		repo:       repo,
		logger:     logger,
	}
}

func (s *importService) ImportRecipe(ctx context.Context, req ImportRecipeRequest) (*recipe.Recipe, error) {
	// Validate the request
	if err := s.validateImportRequest(req); err != nil {
		return nil, fmt.Errorf("validation failed: %w", err)
	}

	// Convert the request to a recipe domain object
	rec := s.convertToRecipe(req)

	// Save the recipe to the database
	savedRecipe, err := s.repo.SaveRecipe(ctx, rec)
	if err != nil {
		s.logger.Error().Err(err).Msg("Failed to save recipe")
		return nil, fmt.Errorf("failed to save recipe: %w", err)
	}

	s.logger.Info().Str("recipe_id", savedRecipe.UUID.String()).Str("name", savedRecipe.Name).Msg("Recipe imported successfully")

	return savedRecipe, nil
}

func (s *importService) validateImportRequest(req ImportRecipeRequest) error {
	if req.Name == "" {
		return fmt.Errorf("recipe name is required")
	}

	if len(req.Steps) == 0 {
		return fmt.Errorf("at least one step is required")
	}

	if len(req.Ingredients) == 0 {
		return fmt.Errorf("at least one ingredient is required")
	}

	return nil
}

func (s *importService) convertToRecipe(req ImportRecipeRequest) recipe.Recipe {
	// Convert steps
	steps := make([]recipe.Step, len(req.Steps))
	for i, step := range req.Steps {
		steps[i] = recipe.Step{
			Order:       step.Order,
			Description: step.Description,
		}
	}

	// Convert ingredients
	ingredients := make([]recipe.RecipeIngredient, len(req.Ingredients))
	for i, ing := range req.Ingredients {
		ingredients[i] = recipe.RecipeIngredient{
			Ingredient: recipe.Ingredient{
				Name: ing.Name,
			},
			Quantity:    ing.Quantity,
			Unit:        recipe.Unit{Name: ing.Unit},
			Preparation: ing.Preparation,
		}
	}

	// Convert labels
	labels := make([]recipe.Label, len(req.Labels))
	for i, label := range req.Labels {
		labels[i] = recipe.Label{
			Name: label,
		}
	}

	return recipe.Recipe{
		Name:        req.Name,
		Description: req.Description,
		CookTime:    req.CookTime,
		PrepTime:    req.PrepTime,
		Servings:    req.Servings,
		Url:         req.URL,
		Steps:       steps,
		Ingredients: ingredients,
		Labels:      labels,
	}
}
