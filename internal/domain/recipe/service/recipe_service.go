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
	ListRecipes(ctx context.Context, limit, offset int, search string, labels []string, sort string) ([]*recipe.Recipe, int, error)
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
	repo  repository.RecipeRepository
	probe recipe.Probe
}

func NewRecipeService(repo repository.RecipeRepository, probe recipe.Probe) RecipeService {
	return &recipeService{
		repo:  repo,
		probe: probe,
	}
}

func (s *recipeService) CreateRecipe(ctx context.Context, r recipe.Recipe) (*recipe.Recipe, error) {
	if r.UUID == uuid.Nil {
		r.UUID = uuid.New()
	}

	result, err := s.repo.SaveRecipe(ctx, r)
	if err != nil {
		s.probe.RecipeError("create", err)
		return nil, err
	}
	s.probe.RecipeCreated(result.Name)
	return result, nil
}

func (s *recipeService) GetRecipe(ctx context.Context, id uuid.UUID) (*recipe.Recipe, error) {
	return s.repo.GetRecipeByID(ctx, id)
}

func (s *recipeService) ListRecipes(ctx context.Context, limit, offset int, search string, labels []string, sort string) ([]*recipe.Recipe, int, error) {
	recipes, total, err := s.repo.ListRecipes(ctx, limit, offset, search, labels, sort)
	if err != nil {
		s.probe.RecipeError("search", err)
		return nil, 0, err
	}
	s.probe.RecipeSearched(total)
	return recipes, total, nil
}

func (s *recipeService) UpdateRecipe(ctx context.Context, id uuid.UUID, r recipe.Recipe) (*recipe.Recipe, error) {
	existingRecipe, err := s.repo.GetRecipeByID(ctx, id)
	if err != nil {
		return nil, err
	}
	if existingRecipe == nil {
		return nil, nil
	}

	result, err := s.repo.UpdateRecipe(ctx, id, r)
	if err != nil {
		s.probe.RecipeError("update", err)
		return nil, err
	}
	s.probe.RecipeUpdated(result.Name)
	return result, nil
}

func (s *recipeService) ArchiveRecipe(ctx context.Context, id uuid.UUID) error {
	r, err := s.repo.GetRecipeByID(ctx, id)
	if err != nil {
		return err
	}
	if r == nil {
		return nil
	}

	if err := s.repo.ArchiveRecipe(ctx, id); err != nil {
		s.probe.RecipeError("archive", err)
		return err
	}
	s.probe.RecipeArchived(id.String())
	return nil
}

func (s *recipeService) RestoreRecipe(ctx context.Context, id uuid.UUID) (*recipe.Recipe, error) {
	result, err := s.repo.RestoreRecipe(ctx, id)
	if err != nil {
		s.probe.RecipeError("restore", err)
		return nil, err
	}
	s.probe.RecipeRestored(id.String())
	return result, nil
}

func (s *recipeService) ListArchivedRecipes(ctx context.Context, limit, offset int) ([]*recipe.Recipe, int, error) {
	return s.repo.ListArchivedRecipes(ctx, limit, offset)
}

func (s *recipeService) AddToMealPlan(ctx context.Context, recipeID uuid.UUID) error {
	if err := s.repo.AddToMealPlan(ctx, recipeID); err != nil {
		s.probe.RecipeError("meal_plan_add", err)
		return err
	}
	s.probe.MealPlanChanged("add", recipeID.String())
	return nil
}

func (s *recipeService) RemoveFromMealPlan(ctx context.Context, recipeID uuid.UUID) error {
	if err := s.repo.RemoveFromMealPlan(ctx, recipeID); err != nil {
		s.probe.RecipeError("meal_plan_remove", err)
		return err
	}
	s.probe.MealPlanChanged("remove", recipeID.String())
	return nil
}

func (s *recipeService) ListMealPlanRecipes(ctx context.Context) ([]*recipe.Recipe, error) {
	return s.repo.ListMealPlanRecipes(ctx)
}
