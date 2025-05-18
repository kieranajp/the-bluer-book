package repository

import (
	"context"

	"github.com/google/uuid"
	"github.com/kieranajp/the-bluer-book/internal/domain/recipe"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/storage/db"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/storage/mapper"
)

type RecipeRepository interface {
	GetRecipeWithSteps(ctx context.Context, uuid string) (recipe.Recipe, error)
	ListRecipesWithIngredients(ctx context.Context) ([]recipe.Recipe, error)
	// ... other methods
}

type recipeRepository struct {
	db *db.Queries
}

func NewRecipeRepository(db *db.Queries) RecipeRepository {
	return &recipeRepository{db: db}
}

func (r *recipeRepository) GetRecipeWithSteps(ctx context.Context, uuidStr string) (recipe.Recipe, error) {
	recipeUUID, err := uuid.Parse(uuidStr)
	if err != nil {
		return recipe.Recipe{}, err
	}

	rows, err := r.db.GetRecipeWithSteps(ctx, recipeUUID)
	if err != nil || len(rows) == 0 {
		return recipe.Recipe{}, err // or custom not found error
	}

	first := rows[0]
	steps := make([]recipe.Step, 0, len(rows))
	for _, row := range rows {
		steps = append(steps, recipe.Step{
			UUID:        row.StepUuid.String(),
			RecipeID:    row.StepRecipeID.UUID.String(),
			StepIndex:   int16(row.StepIndex.Int16),
			Description: mapper.NullStringToString(row.StepDescription),
		})
	}

	return recipe.Recipe{
		UUID:        first.RecipeUuid.String(),
		Name:        first.RecipeName,
		Description: mapper.NullStringToString(first.RecipeDescription),
		Timing:      mapper.NullInt64ToDuration(first.RecipeTiming),
		ServingSize: mapper.NullInt16ToInt16(first.RecipeServingSize),
		Steps:       steps,
	}, nil
}

func (r *recipeRepository) ListRecipesWithIngredients(ctx context.Context) ([]recipe.Recipe, error) {
	rows, err := r.db.ListRecipesWithIngredients(ctx)
	if err != nil {
		return nil, err
	}

	recipeMap := make(map[string]*recipe.Recipe)
	for _, row := range rows {
		recipeID := row.RecipeUuid.String()
		rec, exists := recipeMap[recipeID]
		if !exists {
			rec = &recipe.Recipe{
				UUID:        recipeID,
				Name:        row.RecipeName,
				Description: mapper.NullStringToString(row.RecipeDescription),
				Timing:      mapper.NullInt64ToDuration(row.RecipeTiming),
				ServingSize: mapper.NullInt16ToInt16(row.RecipeServingSize),
				Ingredients: []recipe.RecipeIngredient{},
			}
			recipeMap[recipeID] = rec
		}

		if row.IngredientUuid.Valid {
			ing := recipe.Ingredient{
				UUID: row.IngredientUuid.UUID.String(),
				Name: mapper.NullStringToString(row.IngredientName),
			}
			recIng := recipe.RecipeIngredient{
				RecipeID:   recipeID,
				Ingredient: ing,
				Unit:       recipe.Unit{Name: mapper.NullStringToString(row.IngredientUnit)},
				Quantity:   0,
			}
			if row.IngredientQuantity.Valid {
				recIng.Quantity = row.IngredientQuantity.Float64
			}
			rec.Ingredients = append(rec.Ingredients, recIng)
		}
	}

	recipes := make([]recipe.Recipe, 0, len(recipeMap))
	for _, rec := range recipeMap {
		recipes = append(recipes, *rec)
	}
	return recipes, nil
}
