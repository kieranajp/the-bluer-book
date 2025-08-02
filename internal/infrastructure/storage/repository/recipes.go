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
	GetRecipeByID(ctx context.Context, id uuid.UUID) (*recipe.Recipe, error)
	ListRecipes(ctx context.Context, limit, offset int, search string) ([]*recipe.Recipe, int, error)
	UpdateRecipe(ctx context.Context, id uuid.UUID, recipe recipe.Recipe) (*recipe.Recipe, error)
	ArchiveRecipe(ctx context.Context, id uuid.UUID) error
	RestoreRecipe(ctx context.Context, id uuid.UUID) (*recipe.Recipe, error)
	ListArchivedRecipes(ctx context.Context, limit, offset int) ([]*recipe.Recipe, int, error)
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

func (r *recipeRepository) GetRecipeByID(ctx context.Context, id uuid.UUID) (*recipe.Recipe, error) {
	q := r.db

	// Get basic recipe info
	recipeRow, err := q.GetRecipeByID(ctx, id)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, recipe.RecipeNotFoundError{ID: id}
		}
		return nil, err
	}

	return r.buildRecipeFromRows(ctx, q, recipeRow.Uuid, recipeRow.Name, recipeRow.Description,
		recipeRow.CookTime, recipeRow.PrepTime, recipeRow.Servings, recipeRow.Url,
		recipeRow.CreatedAt, recipeRow.UpdatedAt, recipeRow.MainPhotoUuid, recipeRow.MainPhotoUrl)
}

func (r *recipeRepository) ListRecipes(ctx context.Context, limit, offset int, search string) ([]*recipe.Recipe, int, error) {
	q := r.db

	// Get count first
	count, err := q.CountRecipes(ctx, search)
	if err != nil {
		return nil, 0, err
	}

	// Get recipes
	recipeRows, err := q.ListRecipes(ctx, db.ListRecipesParams{
		Limit:   int32(limit),
		Offset:  int32(offset),
		Column3: search,
	})
	if err != nil {
		return nil, 0, err
	}

	recipes := make([]*recipe.Recipe, len(recipeRows))
	for i, row := range recipeRows {
		rec, err := r.buildRecipeFromRows(ctx, q, row.Uuid, row.Name, row.Description,
			row.CookTime, row.PrepTime, row.Servings, row.Url,
			row.CreatedAt, row.UpdatedAt, row.MainPhotoUuid, row.MainPhotoUrl)
		if err != nil {
			return nil, 0, err
		}
		recipes[i] = rec
	}

	return recipes, int(count), nil
}

func (r *recipeRepository) buildRecipeFromRows(ctx context.Context, q *db.Queries,
	recipeUUID uuid.UUID, name string, description sql.NullString,
	cookTime sql.NullInt32, prepTime sql.NullInt32, servings sql.NullInt16,
	url sql.NullString, createdAt, updatedAt time.Time,
	mainPhotoUUID uuid.NullUUID, mainPhotoURL sql.NullString) (*recipe.Recipe, error) {

	rec := &recipe.Recipe{
		UUID:        recipeUUID,
		Name:        name,
		Description: description.String,
		CookTime:    cookTime.Int32,
		PrepTime:    prepTime.Int32,
		Servings:    servings.Int16,
		Url:         url.String,
		CreatedAt:   createdAt,
		UpdatedAt:   updatedAt,
	}

	// Set main photo if exists
	if mainPhotoUUID.Valid && mainPhotoURL.Valid {
		rec.MainPhoto = &recipe.Photo{
			URL: mainPhotoURL.String,
		}
	}

	// Get steps
	stepRows, err := q.GetStepsByRecipeID(ctx, uuid.NullUUID{UUID: recipeUUID, Valid: true})
	if err != nil {
		return nil, err
	}

	steps := make([]recipe.Step, len(stepRows))
	for i, stepRow := range stepRows {
		steps[i] = recipe.Step{
			Order:       stepRow.StepOrder,
			Description: stepRow.Description.String,
		}
	}
	rec.Steps = steps

	// Get ingredients
	ingredientRows, err := q.GetIngredientsByRecipeID(ctx, recipeUUID)
	if err != nil {
		return nil, err
	}

	ingredients := make([]recipe.RecipeIngredient, len(ingredientRows))
	for i, ingRow := range ingredientRows {
		ingredients[i] = recipe.RecipeIngredient{
			Ingredient: recipe.Ingredient{
				Name: ingRow.IngredientName,
			},
			Unit: recipe.Unit{
				Name:         ingRow.UnitName.String,
				Abbreviation: ingRow.UnitAbbreviation.String,
			},
			Quantity: ingRow.Quantity.Float64,
		}
	}
	rec.Ingredients = ingredients

	// Get labels
	labelRows, err := q.GetLabelsByRecipeID(ctx, recipeUUID)
	if err != nil {
		return nil, err
	}

	labels := make([]recipe.Label, len(labelRows))
	for i, labelRow := range labelRows {
		labels[i] = recipe.Label{
			Name:  labelRow.Name,
			Color: labelRow.Color.String,
		}
	}
	rec.Labels = labels

	// Get photos
	photoRows, err := q.GetPhotosByRecipeID(ctx, recipeUUID)
	if err != nil {
		return nil, err
	}

	photos := make([]recipe.Photo, len(photoRows))
	for i, photoRow := range photoRows {
		photos[i] = recipe.Photo{
			URL: photoRow.Url,
		}
	}
	rec.Photos = photos

	return rec, nil
}

func (r *recipeRepository) UpdateRecipe(ctx context.Context, id uuid.UUID, rec recipe.Recipe) (*recipe.Recipe, error) {
	now := time.Now()

	// Update the recipe
	updatedRecipe, err := r.db.UpdateRecipe(ctx, db.UpdateRecipeParams{
		Uuid:        id,
		Name:        rec.Name,
		Description: sql.NullString{String: rec.Description, Valid: rec.Description != ""},
		CookTime:    sql.NullInt32{Int32: rec.CookTime, Valid: rec.CookTime != 0},
		PrepTime:    sql.NullInt32{Int32: rec.PrepTime, Valid: rec.PrepTime != 0},
		Servings:    sql.NullInt16{Int16: rec.Servings, Valid: rec.Servings != 0},
		MainPhotoID: uuid.NullUUID{}, // TODO: Handle main photo update
		Url:         sql.NullString{String: rec.Url, Valid: rec.Url != ""},
		UpdatedAt:   now,
	})

	if err != nil {
		if err == sql.ErrNoRows {
			return nil, recipe.RecipeNotFoundError{ID: id}
		}
		return nil, err
	}

	// Build complete recipe object
	result, err := r.buildRecipeFromRows(ctx, r.db, updatedRecipe.Uuid, updatedRecipe.Name,
		updatedRecipe.Description, updatedRecipe.CookTime, updatedRecipe.PrepTime,
		updatedRecipe.Servings, updatedRecipe.Url, updatedRecipe.CreatedAt,
		updatedRecipe.UpdatedAt, uuid.NullUUID{}, sql.NullString{})

	if err != nil {
		return nil, err
	}

	r.logger.Info().Str("recipe_id", id.String()).Msg("Recipe updated successfully")
	return result, nil
}

func (r *recipeRepository) ArchiveRecipe(ctx context.Context, id uuid.UUID) error {
	now := time.Now()

	// Archive the recipe (soft delete)
	_, err := r.db.ArchiveRecipe(ctx, db.ArchiveRecipeParams{
		Uuid:       id,
		ArchivedAt: sql.NullTime{Time: now, Valid: true},
	})

	if err != nil {
		if err == sql.ErrNoRows {
			return recipe.RecipeNotFoundError{ID: id}
		}
		return err
	}

	r.logger.Info().Str("recipe_id", id.String()).Msg("Recipe archived successfully")
	return nil
}

func (r *recipeRepository) RestoreRecipe(ctx context.Context, id uuid.UUID) (*recipe.Recipe, error) {
	now := time.Now()

	// Restore the recipe
	restoredRecipe, err := r.db.RestoreRecipe(ctx, db.RestoreRecipeParams{
		Uuid:      id,
		UpdatedAt: now,
	})

	if err != nil {
		if err == sql.ErrNoRows {
			return nil, recipe.ArchivedRecipeNotFoundError{ID: id}
		}
		return nil, err
	}

	// Build complete recipe object
	result, err := r.buildRecipeFromRows(ctx, r.db, restoredRecipe.Uuid, restoredRecipe.Name,
		restoredRecipe.Description, restoredRecipe.CookTime, restoredRecipe.PrepTime,
		restoredRecipe.Servings, restoredRecipe.Url, restoredRecipe.CreatedAt,
		restoredRecipe.UpdatedAt, uuid.NullUUID{}, sql.NullString{})

	if err != nil {
		return nil, err
	}

	r.logger.Info().Str("recipe_id", id.String()).Msg("Recipe restored successfully")
	return result, nil
}

func (r *recipeRepository) ListArchivedRecipes(ctx context.Context, limit, offset int) ([]*recipe.Recipe, int, error) {
	// Get archived recipes
	recipeRows, err := r.db.GetArchivedRecipes(ctx, db.GetArchivedRecipesParams{
		Limit:  int32(limit),
		Offset: int32(offset),
	})
	if err != nil {
		return nil, 0, err
	}

	// Get total count of archived recipes
	count, err := r.db.CountArchivedRecipes(ctx)
	if err != nil {
		return nil, 0, err
	}

	recipes := make([]*recipe.Recipe, len(recipeRows))
	for i, row := range recipeRows {
		rec, err := r.buildRecipeFromRows(ctx, r.db, row.Uuid, row.Name,
			row.Description, row.CookTime, row.PrepTime, row.Servings,
			row.Url, row.CreatedAt, row.UpdatedAt, row.MainPhotoUuid, row.MainPhotoUrl)
		if err != nil {
			return nil, 0, err
		}
		recipes[i] = rec
	}

	return recipes, int(count), nil
}
