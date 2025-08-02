package service

import (
	"context"

	"github.com/google/uuid"
	"github.com/kieranajp/the-bluer-book/internal/domain/recipe"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/storage/repository"
)

type RecipeService interface {
	CreateRecipe(ctx context.Context, recipe recipe.Recipe) (*recipe.Recipe, error)
	GetRecipe(ctx context.Context, id uuid.UUID) (*recipe.Recipe, error)
	ListRecipes(ctx context.Context, limit, offset int, search string) ([]*recipe.Recipe, int, error)
}

type recipeService struct {
	repo repository.RecipeRepository
}

func NewRecipeService(repo repository.RecipeRepository) RecipeService {
	return &recipeService{
		repo: repo,
	}
}

func (s *recipeService) CreateRecipe(ctx context.Context, recipe recipe.Recipe) (*recipe.Recipe, error) {
	// Generate UUID if not provided
	if recipe.UUID == uuid.Nil {
		recipe.UUID = uuid.New()
	}

	return s.repo.SaveRecipe(ctx, recipe)
}

func (s *recipeService) GetRecipe(ctx context.Context, id uuid.UUID) (*recipe.Recipe, error) {
	return s.repo.GetRecipeByID(ctx, id)
}

func (s *recipeService) ListRecipes(ctx context.Context, limit, offset int, search string) ([]*recipe.Recipe, int, error) {
	return s.repo.ListRecipes(ctx, limit, offset, search)
}
