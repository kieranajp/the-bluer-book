package repository

import (
	"context"
	"database/sql"
	"time"

	"github.com/google/uuid"
	"github.com/kieranajp/the-bluer-book/internal/domain/recipe"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/storage/db"
)

type RecipeRepository interface {
	SaveRecipe(ctx context.Context, recipe recipe.Recipe) (*recipe.Recipe, error)
}

type recipeRepository struct {
	db     *db.Queries
	sqlDB  *sql.DB
	logger logger.Logger
}

func NewRecipeRepository(db *db.Queries, sqlDB *sql.DB, logger logger.Logger) RecipeRepository {
	return &recipeRepository{db: db, sqlDB: sqlDB, logger: logger}
}

func (r *recipeRepository) SaveRecipe(ctx context.Context, rec recipe.Recipe) (*recipe.Recipe, error) {
	if rec.UUID == uuid.Nil {
		rec.UUID = uuid.New()
	}

	tx, err := r.sqlDB.BeginTx(ctx, nil)
	if err != nil {
		return nil, err
	}
	q := db.New(tx)
	defer func() {
		if err != nil {
			tx.Rollback()
		} else {
			tx.Commit()
		}
	}()

	now := time.Now()
	// Insert main photo if present
	var mainPhotoID *uuid.UUID
	if rec.MainPhoto != nil && rec.MainPhoto.URL != "" {
		photoUUID := uuid.New()
		photo, err := q.CreatePhoto(ctx, db.CreatePhotoParams{
			Uuid:       photoUUID,
			Url:        rec.MainPhoto.URL,
			EntityType: "recipe",
			EntityID:   rec.UUID,
			CreatedAt:  now,
			UpdatedAt:  now,
		})
		if err != nil {
			return nil, err
		}
		mainPhotoID = &photo.Uuid
		r.logger.Info().Msgf("Inserted main photo for recipe %s: %s", rec.Name, rec.MainPhoto.URL)
	}

	// Insert recipe
	dbRec, err := q.CreateRecipe(ctx, db.CreateRecipeParams{
		Uuid:        rec.UUID,
		Name:        rec.Name,
		Description: sql.NullString{String: rec.Description, Valid: rec.Description != ""},
		CookTime:    sql.NullInt32{Int32: rec.CookTime, Valid: rec.CookTime > 0},
		PrepTime:    sql.NullInt32{Int32: rec.PrepTime, Valid: rec.PrepTime > 0},
		Servings:    sql.NullInt16{Int16: rec.Servings, Valid: rec.Servings > 0},
		MainPhotoID: uuidToNullUUID(mainPhotoID),
		Url:         sql.NullString{String: rec.Url, Valid: rec.Url != ""},
		CreatedAt:   now,
		UpdatedAt:   now,
	})
	if err != nil {
		return nil, err
	}
	recipeID := dbRec.Uuid
	r.logger.Info().Msgf("Inserted recipe: %s (UUID: %s)", rec.Name, recipeID)

	// Insert steps
	for _, step := range rec.Steps {
		stepUUID := uuid.New()
		stepRow, err := q.CreateStep(ctx, db.CreateStepParams{
			Uuid:        stepUUID,
			RecipeID:    uuidToNullUUID(&recipeID),
			StepOrder:   step.Order,
			Description: sql.NullString{String: step.Description, Valid: step.Description != ""},
			CreatedAt:   now,
			UpdatedAt:   now,
		})
		if err != nil {
			return nil, err
		}
		r.logger.Info().Msgf("Inserted step %d for recipe %s (UUID: %s)", step.Order, rec.Name, recipeID)
		// Insert step photos
		for _, photo := range step.Photos {
			_, err := q.CreatePhoto(ctx, db.CreatePhotoParams{
				Uuid:       uuid.New(),
				Url:        photo.URL,
				EntityType: "step",
				EntityID:   stepRow.Uuid,
				CreatedAt:  now,
				UpdatedAt:  now,
			})
			if err != nil {
				return nil, err
			}
			r.logger.Info().Msgf("Inserted step photo for step %d: %s", step.Order, photo.URL)
		}
	}

	// Insert ingredients and recipe_ingredient
	ingredientSet := make(map[uuid.UUID]bool)
	for _, ri := range rec.Ingredients {
		// Ingredient
		var ingRow db.Ingredient
		ingRow, err = q.GetIngredientByName(ctx, ri.Ingredient.Name)
		if err == sql.ErrNoRows {
			ingRow, err = q.CreateIngredient(ctx, db.CreateIngredientParams{
				Uuid:      uuid.New(),
				Name:      ri.Ingredient.Name,
				CreatedAt: now,
				UpdatedAt: now,
			})
			if err != nil {
				return nil, err
			}
			r.logger.Info().Msgf("Inserted new ingredient: %s (UUID: %s)", ri.Ingredient.Name, ingRow.Uuid)
		} else if err != nil {
			return nil, err
		}
		if ingredientSet[ingRow.Uuid] {
			continue // already inserted for this recipe
		}
		ingredientSet[ingRow.Uuid] = true
		// Unit
		var unitRow db.Unit
		unitRow, err = q.GetUnitByName(ctx, ri.Unit.Name)
		if err == sql.ErrNoRows {
			unitRow, err = q.CreateUnit(ctx, db.CreateUnitParams{
				Uuid:         uuid.New(),
				Name:         ri.Unit.Name,
				Abbreviation: sql.NullString{String: ri.Unit.Abbreviation, Valid: ri.Unit.Abbreviation != ""},
				CreatedAt:    now,
				UpdatedAt:    now,
			})
			if err != nil {
				return nil, err
			}
			r.logger.Info().Msgf("Inserted new unit: %s (UUID: %s)", ri.Unit.Name, unitRow.Uuid)
		} else if err != nil {
			return nil, err
		}
		// RecipeIngredient
		_, err = q.CreateRecipeIngredient(ctx, db.CreateRecipeIngredientParams{
			RecipeID:     recipeID,
			IngredientID: ingRow.Uuid,
			UnitID:       uuidToNullUUID(&unitRow.Uuid),
			Quantity:     sql.NullFloat64{Float64: ri.Quantity, Valid: true},
			CreatedAt:    now,
			UpdatedAt:    now,
		})
		if err != nil {
			return nil, err
		}
		r.logger.Info().Msgf("Linked ingredient %s to recipe %s", ri.Ingredient.Name, rec.Name)
	}

	// Insert labels and recipe_label
	for _, label := range rec.Labels {
		var labelRow db.Label
		labelRow, err = q.GetLabelByName(ctx, label.Name)
		if err == sql.ErrNoRows {
			labelRow, err = q.CreateLabel(ctx, db.CreateLabelParams{
				Uuid:      uuid.New(),
				Name:      label.Name,
				Color:     sql.NullString{String: label.Color, Valid: label.Color != ""},
				CreatedAt: now,
				UpdatedAt: now,
			})
			if err != nil {
				return nil, err
			}
			r.logger.Info().Msgf("Inserted new label: %s (UUID: %s)", label.Name, labelRow.Uuid)
		} else if err != nil {
			return nil, err
		}
		_, err = q.CreateRecipeLabel(ctx, db.CreateRecipeLabelParams{
			RecipeID:  recipeID,
			LabelID:   labelRow.Uuid,
			CreatedAt: now,
			UpdatedAt: now,
		})
		if err != nil {
			return nil, err
		}
		r.logger.Info().Msgf("Linked label %s to recipe %s", label.Name, rec.Name)
	}

	// Insert recipe photos (not main photo)
	for _, photo := range rec.Photos {
		if rec.MainPhoto != nil && photo.URL == rec.MainPhoto.URL {
			continue // already inserted as main photo
		}
		_, err := q.CreatePhoto(ctx, db.CreatePhotoParams{
			Uuid:       uuid.New(),
			Url:        photo.URL,
			EntityType: "recipe",
			EntityID:   recipeID,
			CreatedAt:  now,
			UpdatedAt:  now,
		})
		if err != nil {
			return nil, err
		}
		r.logger.Info().Msgf("Inserted recipe photo for recipe %s: %s", rec.Name, photo.URL)
	}

	r.logger.Info().Msgf("Successfully saved recipe: %s (UUID: %s)", rec.Name, recipeID)

	// Update the recipe with the saved UUID and timestamps
	rec.UUID = recipeID
	rec.CreatedAt = now
	rec.UpdatedAt = now

	return &rec, nil
}

func uuidToNullUUID(id *uuid.UUID) uuid.NullUUID {
	if id == nil {
		return uuid.NullUUID{Valid: false}
	}
	return uuid.NullUUID{UUID: *id, Valid: true}
}
