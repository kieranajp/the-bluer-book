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
	UpdateRecipe(ctx context.Context, id uuid.UUID, recipe recipe.Recipe) (*recipe.Recipe, error)

	// Archival methods
	ArchiveRecipe(ctx context.Context, id uuid.UUID) error
	RestoreRecipe(ctx context.Context, id uuid.UUID) (*recipe.Recipe, error)
	ListArchivedRecipes(ctx context.Context, limit, offset int) ([]*recipe.Recipe, int, error)

	// Meal planning methods
	AddToMealPlan(ctx context.Context, recipeID uuid.UUID) error
	RemoveFromMealPlan(ctx context.Context, recipeID uuid.UUID) error
	ListMealPlanRecipes(ctx context.Context) ([]*recipe.Recipe, error)
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

func (s *recipeService) UpdateRecipe(ctx context.Context, id uuid.UUID, recipe recipe.Recipe) (*recipe.Recipe, error) {
	// Check if recipe exists and is not already archived
	existingRecipe, err := s.repo.GetRecipeByID(ctx, id)
	if err != nil {
		return nil, err
	}
	if existingRecipe == nil {
		return nil, nil // Recipe not found
	}

	return s.repo.UpdateRecipe(ctx, id, recipe)
}

func (s *recipeService) ArchiveRecipe(ctx context.Context, id uuid.UUID) error {
	// Check if recipe exists and is not already archived
	recipe, err := s.repo.GetRecipeByID(ctx, id)
	if err != nil {
		return err
	}
	if recipe == nil {
		return nil // Recipe not found or already archived
	}

	return s.repo.ArchiveRecipe(ctx, id)
}

func (s *recipeService) RestoreRecipe(ctx context.Context, id uuid.UUID) (*recipe.Recipe, error) {
	return s.repo.RestoreRecipe(ctx, id)
}

func (s *recipeService) ListArchivedRecipes(ctx context.Context, limit, offset int) ([]*recipe.Recipe, int, error) {
	return s.repo.ListArchivedRecipes(ctx, limit, offset)
}

func (s *recipeService) AddToMealPlan(ctx context.Context, recipeID uuid.UUID) error {
	return s.repo.AddToMealPlan(ctx, recipeID)
}

func (s *recipeService) RemoveFromMealPlan(ctx context.Context, recipeID uuid.UUID) error {
	return s.repo.RemoveFromMealPlan(ctx, recipeID)
}

func (s *recipeService) ListMealPlanRecipes(ctx context.Context) ([]*recipe.Recipe, error) {
	return s.repo.ListMealPlanRecipes(ctx)
}
