package repository

import (
	"context"

	"github.com/kieranajp/the-bluer-book/internal/domain/recipe"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/storage/db"
)

type RecipeRepository interface {
	SaveRecipe(ctx context.Context, recipe recipe.Recipe) error
}

type recipeRepository struct {
	db *db.Queries
}

func NewRecipeRepository(db *db.Queries) RecipeRepository {
	return &recipeRepository{db: db}
}

func (r *recipeRepository) SaveRecipe(ctx context.Context, recipe recipe.Recipe) error {
	return nil
}
