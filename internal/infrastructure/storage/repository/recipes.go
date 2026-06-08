package repository

import (
	"context"
	"database/sql"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/kieranajp/the-bluer-book/internal/domain/recipe"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/storage/db"
)

type RecipeRepository interface {
	SaveRecipe(ctx context.Context, recipe recipe.Recipe) (*recipe.Recipe, error)
	GetRecipeByID(ctx context.Context, id uuid.UUID) (*recipe.Recipe, error)
	ListRecipes(ctx context.Context, limit, offset int, search string, labels []string, sort string) ([]*recipe.Recipe, int, error)
	UpdateRecipe(ctx context.Context, id uuid.UUID, recipe recipe.Recipe) (*recipe.Recipe, error)
	ArchiveRecipe(ctx context.Context, id uuid.UUID) error
	RestoreRecipe(ctx context.Context, id uuid.UUID) (*recipe.Recipe, error)
	ListArchivedRecipes(ctx context.Context, limit, offset int) ([]*recipe.Recipe, int, error)

	// Meal planning methods
	AddToMealPlan(ctx context.Context, recipeID uuid.UUID) error
	RemoveFromMealPlan(ctx context.Context, recipeID uuid.UUID) error
	ListMealPlanRecipes(ctx context.Context) ([]*recipe.Recipe, error)

	// Label browsing
	ListLabels(ctx context.Context) ([]recipe.LabelSummary, error)

	// Lookup methods
	ListUnits(ctx context.Context) ([]recipe.Unit, error)
	ListIngredients(ctx context.Context) ([]recipe.Ingredient, error)
}

type recipeRepository struct {
	sqlDB  *sql.DB
	logger logger.Logger
}

func NewRecipeRepository(sqlDB *sql.DB, logger logger.Logger) RecipeRepository {
	return &recipeRepository{sqlDB: sqlDB, logger: logger}
}

func (r *recipeRepository) inTx(ctx context.Context, fn func(q *db.Queries) error) error {
	return InHomeTx(ctx, r.sqlDB, fn)
}

func (r *recipeRepository) SaveRecipe(ctx context.Context, rec recipe.Recipe) (*recipe.Recipe, error) {
	if rec.UUID == uuid.Nil {
		rec.UUID = uuid.New()
	}
	now := time.Now()

	var saved recipe.Recipe
	err := r.inTx(ctx, func(q *db.Queries) error {
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
				return err
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
			return err
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
				return err
			}
			r.logger.Info().Msgf("Inserted step %d for recipe %s (UUID: %s)", step.Order, rec.Name, recipeID)
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
					return err
				}
				r.logger.Info().Msgf("Inserted step photo for step %d: %s", step.Order, photo.URL)
			}
		}

		// Insert ingredients and recipe_ingredient
		ingredientSet := make(map[uuid.UUID]bool)
		for _, ri := range rec.Ingredients {
			ingRow, err := q.GetIngredientByName(ctx, ri.Ingredient.Name)
			if err == sql.ErrNoRows {
				ingRow, err = q.CreateIngredient(ctx, db.CreateIngredientParams{
					Uuid:      uuid.New(),
					Name:      ri.Ingredient.Name,
					CreatedAt: now,
					UpdatedAt: now,
				})
				if err != nil {
					return err
				}
				r.logger.Info().Msgf("Inserted new ingredient: %s (UUID: %s)", ri.Ingredient.Name, ingRow.Uuid)
			} else if err != nil {
				return err
			}
			if ingredientSet[ingRow.Uuid] {
				continue
			}
			ingredientSet[ingRow.Uuid] = true

			unitName := normalizeUnitName(ri.Unit.Name)
			var unitID uuid.NullUUID
			if unitName != "" {
				unitRow, err := q.GetUnitByName(ctx, unitName)
				if err == sql.ErrNoRows {
					unitRow, err = q.CreateUnit(ctx, db.CreateUnitParams{
						Uuid:         uuid.New(),
						Name:         unitName,
						Abbreviation: sql.NullString{String: ri.Unit.Abbreviation, Valid: ri.Unit.Abbreviation != ""},
						CreatedAt:    now,
						UpdatedAt:    now,
					})
					if err != nil {
						return err
					}
					r.logger.Info().Msgf("Inserted new unit: %s (UUID: %s)", unitName, unitRow.Uuid)
				} else if err != nil {
					return err
				}
				unitID = uuidToNullUUID(&unitRow.Uuid)
			}

			if _, err := q.CreateRecipeIngredient(ctx, db.CreateRecipeIngredientParams{
				RecipeID:     recipeID,
				IngredientID: ingRow.Uuid,
				UnitID:       unitID,
				Quantity:     sql.NullFloat64{Float64: ri.Quantity, Valid: true},
				Preparation:  sql.NullString{String: ri.Preparation, Valid: ri.Preparation != ""},
				Component:    sql.NullString{String: ri.Component, Valid: ri.Component != ""},
				CreatedAt:    now,
				UpdatedAt:    now,
			}); err != nil {
				return err
			}
			r.logger.Info().Msgf("Linked ingredient %s to recipe %s", ri.Ingredient.Name, rec.Name)
		}

		// Insert labels and recipe_label
		for _, label := range rec.Labels {
			labelRow, err := q.GetLabelByTypeAndName(ctx, db.GetLabelByTypeAndNameParams{
				Type: label.Type,
				Name: label.Name,
			})
			if err == sql.ErrNoRows {
				labelRow, err = q.CreateLabel(ctx, db.CreateLabelParams{
					Uuid:      uuid.New(),
					Type:      label.Type,
					Name:      label.Name,
					CreatedAt: now,
					UpdatedAt: now,
				})
				if err != nil {
					return err
				}
				r.logger.Info().Msgf("Inserted new label: %s:%s (UUID: %s)", label.Type, label.Name, labelRow.Uuid)
			} else if err != nil {
				return err
			}
			if _, err := q.CreateRecipeLabel(ctx, db.CreateRecipeLabelParams{
				RecipeID:  recipeID,
				LabelID:   labelRow.Uuid,
				CreatedAt: now,
				UpdatedAt: now,
			}); err != nil {
				return err
			}
			r.logger.Info().Msgf("Linked label %s:%s to recipe %s", label.Type, label.Name, rec.Name)
		}

		// Insert recipe photos (not main photo)
		for _, photo := range rec.Photos {
			if rec.MainPhoto != nil && photo.URL == rec.MainPhoto.URL {
				continue
			}
			if _, err := q.CreatePhoto(ctx, db.CreatePhotoParams{
				Uuid:       uuid.New(),
				Url:        photo.URL,
				EntityType: "recipe",
				EntityID:   recipeID,
				CreatedAt:  now,
				UpdatedAt:  now,
			}); err != nil {
				return err
			}
			r.logger.Info().Msgf("Inserted recipe photo for recipe %s: %s", rec.Name, photo.URL)
		}

		r.logger.Info().Msgf("Successfully saved recipe: %s (UUID: %s)", rec.Name, recipeID)

		rec.UUID = recipeID
		rec.CreatedAt = now
		rec.UpdatedAt = now
		saved = rec
		return nil
	})
	if err != nil {
		return nil, err
	}
	return &saved, nil
}

func uuidToNullUUID(id *uuid.UUID) uuid.NullUUID {
	if id == nil {
		return uuid.NullUUID{Valid: false}
	}
	return uuid.NullUUID{UUID: *id, Valid: true}
}

func normalizeUnitName(name string) string {
	return strings.ToLower(strings.TrimSpace(name))
}

func (r *recipeRepository) GetRecipeByID(ctx context.Context, id uuid.UUID) (*recipe.Recipe, error) {
	var result *recipe.Recipe
	err := r.inTx(ctx, func(q *db.Queries) error {
		recipeRow, err := q.GetRecipeByID(ctx, id)
		if err != nil {
			if err == sql.ErrNoRows {
				return recipe.RecipeNotFoundError{ID: id}
			}
			return err
		}
		rec, err := r.buildRecipeFromRows(ctx, q, recipeRow.Uuid, recipeRow.Name, recipeRow.Description,
			recipeRow.CookTime, recipeRow.PrepTime, recipeRow.Servings, recipeRow.Url,
			recipeRow.CreatedAt, recipeRow.UpdatedAt, recipeRow.MainPhotoUuid, recipeRow.MainPhotoUrl)
		if err != nil {
			return err
		}
		result = rec
		return nil
	})
	if err != nil {
		return nil, err
	}
	return result, nil
}

func (r *recipeRepository) ListRecipes(ctx context.Context, limit, offset int, search string, labels []string, sort string) ([]*recipe.Recipe, int, error) {
	var recipes []*recipe.Recipe
	var total int

	err := r.inTx(ctx, func(q *db.Queries) error {
		var searchParam sql.NullString
		if search != "" {
			searchParam = sql.NullString{String: search, Valid: true}
		}

		if len(labels) == 0 {
			count, err := q.CountRecipes(ctx, search)
			if err != nil {
				return err
			}

			recipeRows, err := q.ListRecipes(ctx, db.ListRecipesParams{
				Limit:   int32(limit),
				Offset:  int32(offset),
				Column3: search,
				Column4: sort,
			})
			if err != nil {
				return err
			}

			recipes = make([]*recipe.Recipe, len(recipeRows))
			for i, row := range recipeRows {
				rec, err := r.buildRecipeFromRows(ctx, q, row.Uuid, row.Name, row.Description,
					row.CookTime, row.PrepTime, row.Servings, row.Url,
					row.CreatedAt, row.UpdatedAt, row.MainPhotoUuid, row.MainPhotoUrl)
				if err != nil {
					return err
				}
				rec.IsInMealPlan = row.IsInMealPlan
				recipes[i] = rec
			}
			total = int(count)
			return nil
		}

		count, err := q.CountRecipesWithLabels(ctx, db.CountRecipesWithLabelsParams{
			Search:    searchParam,
			LabelKeys: labels,
		})
		if err != nil {
			return err
		}

		recipeRows, err := q.ListRecipesWithMealPlanStatusAndLabels(ctx, db.ListRecipesWithMealPlanStatusAndLabelsParams{
			Search:       searchParam,
			LabelKeys:    labels,
			RecipeLimit:  int32(limit),
			RecipeOffset: int32(offset),
		})
		if err != nil {
			return err
		}

		recipes = make([]*recipe.Recipe, len(recipeRows))
		for i, row := range recipeRows {
			rec, err := r.buildRecipeFromRows(ctx, q, row.Uuid, row.Name, row.Description,
				row.CookTime, row.PrepTime, row.Servings, row.Url,
				row.CreatedAt, row.UpdatedAt, row.MainPhotoUuid, row.MainPhotoUrl)
			if err != nil {
				return err
			}
			rec.IsInMealPlan = row.IsInMealPlan
			recipes[i] = rec
		}
		total = int(count)
		return nil
	})
	if err != nil {
		return nil, 0, err
	}
	return recipes, total, nil
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

	if mainPhotoUUID.Valid && mainPhotoURL.Valid {
		rec.MainPhoto = &recipe.Photo{URL: mainPhotoURL.String}
	}

	stepRows, err := q.GetStepsByRecipeID(ctx, uuid.NullUUID{UUID: recipeUUID, Valid: true})
	if err != nil {
		return nil, err
	}
	steps := make([]recipe.Step, len(stepRows))
	for i, stepRow := range stepRows {
		steps[i] = recipe.Step{Order: stepRow.StepOrder, Description: stepRow.Description.String}
	}
	rec.Steps = steps

	ingredientRows, err := q.GetIngredientsByRecipeID(ctx, recipeUUID)
	if err != nil {
		return nil, err
	}
	ingredients := make([]recipe.RecipeIngredient, len(ingredientRows))
	for i, ingRow := range ingredientRows {
		ingredients[i] = recipe.RecipeIngredient{
			Ingredient:  recipe.Ingredient{Name: ingRow.IngredientName},
			Unit:        recipe.Unit{Name: ingRow.UnitName.String, Abbreviation: ingRow.UnitAbbreviation.String},
			Quantity:    ingRow.Quantity.Float64,
			Preparation: ingRow.Preparation.String,
			Component:   ingRow.Component.String,
		}
	}
	rec.Ingredients = ingredients

	labelRows, err := q.GetLabelsByRecipeID(ctx, recipeUUID)
	if err != nil {
		return nil, err
	}
	labels := make([]recipe.Label, len(labelRows))
	for i, labelRow := range labelRows {
		labels[i] = recipe.Label{Type: labelRow.Type, Name: labelRow.Name}
	}
	rec.Labels = labels

	photoRows, err := q.GetPhotosByRecipeID(ctx, recipeUUID)
	if err != nil {
		return nil, err
	}
	photos := make([]recipe.Photo, len(photoRows))
	for i, photoRow := range photoRows {
		photos[i] = recipe.Photo{URL: photoRow.Url}
	}
	rec.Photos = photos

	return rec, nil
}

func (r *recipeRepository) UpdateRecipe(ctx context.Context, id uuid.UUID, rec recipe.Recipe) (*recipe.Recipe, error) {
	now := time.Now()
	var updated recipe.Recipe

	err := r.inTx(ctx, func(q *db.Queries) error {
		// Resolve the main photo. We reuse the existing photo row when the
		// URL is unchanged (the common case — editing a recipe must not drop
		// or duplicate its photo) and only create a new row for a genuinely
		// new URL. A nil MainPhoto clears the association.
		var mainPhotoID *uuid.UUID
		if rec.MainPhoto != nil && rec.MainPhoto.URL != "" {
			existing, err := q.GetPhotoByUrlAndEntity(ctx, db.GetPhotoByUrlAndEntityParams{
				Url:        rec.MainPhoto.URL,
				EntityType: "recipe",
				EntityID:   id,
			})
			switch err {
			case nil:
				mainPhotoID = &existing.Uuid
			case sql.ErrNoRows:
				photo, err := q.CreatePhoto(ctx, db.CreatePhotoParams{
					Uuid:       uuid.New(),
					Url:        rec.MainPhoto.URL,
					EntityType: "recipe",
					EntityID:   id,
					CreatedAt:  now,
					UpdatedAt:  now,
				})
				if err != nil {
					return err
				}
				mainPhotoID = &photo.Uuid
			default:
				return err
			}
		}

		updatedRecipe, err := q.UpdateRecipe(ctx, db.UpdateRecipeParams{
			Uuid:        id,
			Name:        rec.Name,
			Description: sql.NullString{String: rec.Description, Valid: rec.Description != ""},
			CookTime:    sql.NullInt32{Int32: rec.CookTime, Valid: rec.CookTime > 0},
			PrepTime:    sql.NullInt32{Int32: rec.PrepTime, Valid: rec.PrepTime > 0},
			Servings:    sql.NullInt16{Int16: rec.Servings, Valid: rec.Servings > 0},
			MainPhotoID: uuidToNullUUID(mainPhotoID),
			Url:         sql.NullString{String: rec.Url, Valid: rec.Url != ""},
			UpdatedAt:   now,
		})
		if err != nil {
			if err == sql.ErrNoRows {
				return recipe.RecipeNotFoundError{ID: id}
			}
			return err
		}

		recipeID := updatedRecipe.Uuid
		recipeNullUUID := uuid.NullUUID{UUID: recipeID, Valid: true}

		if err := q.DeleteStepPhotosByRecipeID(ctx, recipeNullUUID); err != nil {
			return err
		}
		if err := q.DeleteStepsByRecipeID(ctx, recipeNullUUID); err != nil {
			return err
		}
		if err := q.DeleteRecipeIngredientsByRecipeID(ctx, recipeID); err != nil {
			return err
		}
		if err := q.DeleteRecipeLabelsByRecipeID(ctx, recipeID); err != nil {
			return err
		}

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
				return err
			}
			r.logger.Info().Msgf("Inserted step %d for recipe %s", step.Order, recipeID)
			for _, photo := range step.Photos {
				if _, err := q.CreatePhoto(ctx, db.CreatePhotoParams{
					Uuid:       uuid.New(),
					Url:        photo.URL,
					EntityType: "step",
					EntityID:   stepRow.Uuid,
					CreatedAt:  now,
					UpdatedAt:  now,
				}); err != nil {
					return err
				}
			}
		}

		ingredientSet := make(map[uuid.UUID]bool)
		for _, ri := range rec.Ingredients {
			ingRow, err := q.GetIngredientByName(ctx, ri.Ingredient.Name)
			if err == sql.ErrNoRows {
				ingRow, err = q.CreateIngredient(ctx, db.CreateIngredientParams{
					Uuid:      uuid.New(),
					Name:      ri.Ingredient.Name,
					CreatedAt: now,
					UpdatedAt: now,
				})
				if err != nil {
					return err
				}
			} else if err != nil {
				return err
			}
			if ingredientSet[ingRow.Uuid] {
				continue
			}
			ingredientSet[ingRow.Uuid] = true

			unitName := normalizeUnitName(ri.Unit.Name)
			var unitID uuid.NullUUID
			if unitName != "" {
				unitRow, err := q.GetUnitByName(ctx, unitName)
				if err == sql.ErrNoRows {
					unitRow, err = q.CreateUnit(ctx, db.CreateUnitParams{
						Uuid:         uuid.New(),
						Name:         unitName,
						Abbreviation: sql.NullString{String: ri.Unit.Abbreviation, Valid: ri.Unit.Abbreviation != ""},
						CreatedAt:    now,
						UpdatedAt:    now,
					})
					if err != nil {
						return err
					}
				} else if err != nil {
					return err
				}
				unitID = uuidToNullUUID(&unitRow.Uuid)
			}

			if _, err := q.CreateRecipeIngredient(ctx, db.CreateRecipeIngredientParams{
				RecipeID:     recipeID,
				IngredientID: ingRow.Uuid,
				UnitID:       unitID,
				Quantity:     sql.NullFloat64{Float64: ri.Quantity, Valid: true},
				Preparation:  sql.NullString{String: ri.Preparation, Valid: ri.Preparation != ""},
				Component:    sql.NullString{String: ri.Component, Valid: ri.Component != ""},
				CreatedAt:    now,
				UpdatedAt:    now,
			}); err != nil {
				return err
			}
		}

		for _, label := range rec.Labels {
			labelRow, err := q.GetLabelByTypeAndName(ctx, db.GetLabelByTypeAndNameParams{
				Type: label.Type,
				Name: label.Name,
			})
			if err == sql.ErrNoRows {
				labelRow, err = q.CreateLabel(ctx, db.CreateLabelParams{
					Uuid:      uuid.New(),
					Type:      label.Type,
					Name:      label.Name,
					CreatedAt: now,
					UpdatedAt: now,
				})
				if err != nil {
					return err
				}
			} else if err != nil {
				return err
			}
			if _, err := q.CreateRecipeLabel(ctx, db.CreateRecipeLabelParams{
				RecipeID:  recipeID,
				LabelID:   labelRow.Uuid,
				CreatedAt: now,
				UpdatedAt: now,
			}); err != nil {
				return err
			}
		}

		r.logger.Info().Str("recipe_id", id.String()).Msg("Recipe updated successfully")

		rec.UUID = recipeID
		rec.CreatedAt = updatedRecipe.CreatedAt
		rec.UpdatedAt = now
		updated = rec
		return nil
	})
	if err != nil {
		return nil, err
	}
	return &updated, nil
}

func (r *recipeRepository) ArchiveRecipe(ctx context.Context, id uuid.UUID) error {
	now := time.Now()
	return r.inTx(ctx, func(q *db.Queries) error {
		_, err := q.ArchiveRecipe(ctx, db.ArchiveRecipeParams{
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
	})
}

func (r *recipeRepository) RestoreRecipe(ctx context.Context, id uuid.UUID) (*recipe.Recipe, error) {
	now := time.Now()
	var result *recipe.Recipe
	err := r.inTx(ctx, func(q *db.Queries) error {
		restoredRecipe, err := q.RestoreRecipe(ctx, db.RestoreRecipeParams{
			Uuid:      id,
			UpdatedAt: now,
		})
		if err != nil {
			if err == sql.ErrNoRows {
				return recipe.ArchivedRecipeNotFoundError{ID: id}
			}
			return err
		}

		built, err := r.buildRecipeFromRows(ctx, q, restoredRecipe.Uuid, restoredRecipe.Name,
			restoredRecipe.Description, restoredRecipe.CookTime, restoredRecipe.PrepTime,
			restoredRecipe.Servings, restoredRecipe.Url, restoredRecipe.CreatedAt,
			restoredRecipe.UpdatedAt, uuid.NullUUID{}, sql.NullString{})
		if err != nil {
			return err
		}
		result = built
		r.logger.Info().Str("recipe_id", id.String()).Msg("Recipe restored successfully")
		return nil
	})
	if err != nil {
		return nil, err
	}
	return result, nil
}

func (r *recipeRepository) ListArchivedRecipes(ctx context.Context, limit, offset int) ([]*recipe.Recipe, int, error) {
	var recipes []*recipe.Recipe
	var total int
	err := r.inTx(ctx, func(q *db.Queries) error {
		recipeRows, err := q.GetArchivedRecipes(ctx, db.GetArchivedRecipesParams{
			Limit:  int32(limit),
			Offset: int32(offset),
		})
		if err != nil {
			return err
		}
		count, err := q.CountArchivedRecipes(ctx)
		if err != nil {
			return err
		}

		recipes = make([]*recipe.Recipe, len(recipeRows))
		for i, row := range recipeRows {
			rec, err := r.buildRecipeFromRows(ctx, q, row.Uuid, row.Name,
				row.Description, row.CookTime, row.PrepTime, row.Servings,
				row.Url, row.CreatedAt, row.UpdatedAt, row.MainPhotoUuid, row.MainPhotoUrl)
			if err != nil {
				return err
			}
			recipes[i] = rec
		}
		total = int(count)
		return nil
	})
	if err != nil {
		return nil, 0, err
	}
	return recipes, total, nil
}

func (r *recipeRepository) AddToMealPlan(ctx context.Context, recipeID uuid.UUID) error {
	return r.inTx(ctx, func(q *db.Queries) error {
		return q.AddToMealPlan(ctx, recipeID)
	})
}

func (r *recipeRepository) RemoveFromMealPlan(ctx context.Context, recipeID uuid.UUID) error {
	return r.inTx(ctx, func(q *db.Queries) error {
		return q.RemoveFromMealPlan(ctx, recipeID)
	})
}

func (r *recipeRepository) ListMealPlanRecipes(ctx context.Context) ([]*recipe.Recipe, error) {
	var recipes []*recipe.Recipe
	err := r.inTx(ctx, func(q *db.Queries) error {
		rows, err := q.ListMealPlanRecipes(ctx)
		if err != nil {
			return err
		}
		recipes = make([]*recipe.Recipe, len(rows))
		for i, row := range rows {
			rec, err := r.buildRecipeFromRows(ctx, q, row.Uuid, row.Name,
				row.Description, row.CookTime, row.PrepTime, row.Servings,
				row.Url, row.CreatedAt, row.UpdatedAt, row.MainPhotoUuid, row.MainPhotoUrl)
			if err != nil {
				return err
			}
			rec.IsInMealPlan = row.IsInMealPlan
			recipes[i] = rec
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return recipes, nil
}

func (r *recipeRepository) ListLabels(ctx context.Context) ([]recipe.LabelSummary, error) {
	var out []recipe.LabelSummary
	err := r.inTx(ctx, func(q *db.Queries) error {
		rows, err := q.ListLabels(ctx)
		if err != nil {
			return err
		}
		out = make([]recipe.LabelSummary, len(rows))
		for i, row := range rows {
			out[i] = recipe.LabelSummary{Type: row.Type, Name: row.Name, Uses: int(row.Uses)}
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (r *recipeRepository) ListUnits(ctx context.Context) ([]recipe.Unit, error) {
	var units []recipe.Unit
	err := r.inTx(ctx, func(q *db.Queries) error {
		rows, err := q.ListUnits(ctx)
		if err != nil {
			return err
		}
		units = make([]recipe.Unit, len(rows))
		for i, row := range rows {
			units[i] = recipe.Unit{Name: row.Name, Abbreviation: row.Abbreviation.String}
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return units, nil
}

func (r *recipeRepository) ListIngredients(ctx context.Context) ([]recipe.Ingredient, error) {
	var ingredients []recipe.Ingredient
	err := r.inTx(ctx, func(q *db.Queries) error {
		rows, err := q.ListIngredients(ctx)
		if err != nil {
			return err
		}
		ingredients = make([]recipe.Ingredient, len(rows))
		for i, row := range rows {
			ingredients[i] = recipe.Ingredient{Name: row.Name}
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return ingredients, nil
}
