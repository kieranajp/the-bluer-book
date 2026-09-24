package repository

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
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

	// Photos
	SetMainPhoto(ctx context.Context, recipeID uuid.UUID, url string) error

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

func (r *recipeRepository) SaveRecipe(ctx context.Context, rec recipe.Recipe) (*recipe.Recipe, error) {
	if rec.UUID == uuid.Nil {
		rec.UUID = uuid.New()
	}

	err := InHomeTx(ctx, r.sqlDB, func(q *db.Queries) error {
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
					return err
				}
				r.logger.Info().Msgf("Inserted step photo for step %d: %s", step.Order, photo.URL)
			}
		}

		// Insert ingredients and recipe_ingredient
		if err := r.writeRecipeIngredients(ctx, q, recipeID, rec.Name, rec.Ingredients, now); err != nil {
			return err
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
			_, err = q.CreateRecipeLabel(ctx, db.CreateRecipeLabelParams{
				RecipeID:  recipeID,
				LabelID:   labelRow.Uuid,
				CreatedAt: now,
				UpdatedAt: now,
			})
			if err != nil {
				return err
			}
			r.logger.Info().Msgf("Linked label %s:%s to recipe %s", label.Type, label.Name, rec.Name)
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
				return err
			}
			r.logger.Info().Msgf("Inserted recipe photo for recipe %s: %s", rec.Name, photo.URL)
		}

		r.logger.Info().Msgf("Successfully saved recipe: %s (UUID: %s)", rec.Name, recipeID)

		// Update the recipe with the saved UUID and timestamps
		rec.UUID = recipeID
		rec.CreatedAt = now
		rec.UpdatedAt = now

		return nil
	})
	if err != nil {
		return nil, err
	}

	return &rec, nil
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

// resolveIngredient maps a free-text ingredient name to its row, minting a
// new one only when nothing matches. The second return is a count qualifier
// stripped from the name on the way ("garlic cloves" -> "cloves", resolved to
// garlic); the caller moves it onto the recipe line. Empty when the name
// resolved whole or nothing was stripped.
func (r *recipeRepository) resolveIngredient(ctx context.Context, q *db.Queries, name string, now time.Time) (uuid.UUID, string, error) {
	match, err := q.FindIngredientByName(ctx, name)
	switch {
	case err == nil:
		return match.Uuid, "", nil
	case !errors.Is(err, sql.ErrNoRows):
		return uuid.Nil, "", err
	}

	// A free-text name can carry a count qualifier the book stores on the
	// recipe line instead — "garlic cloves" is garlic. Strip a trailing
	// qualifier noun and create the base whenever the whole name matches
	// nothing, so the outcome does not depend on what the home happens to
	// have: "garlic cloves" resolves to garlic whether or not a bare "garlic"
	// row already exists. Only a closed list of count nouns is stripped, so
	// ordinary multi-word ingredients are never mangled — "onions" is a real
	// name and resolves before any splitting is attempted.
	base, qualifier := splitIngredientQualifier(name)
	if qualifier != "" {
		created, err := q.CreateIngredient(ctx, db.CreateIngredientParams{
			Uuid:      uuid.New(),
			Name:      strings.TrimSpace(base),
			CreatedAt: now,
			UpdatedAt: now,
		})
		if err != nil {
			return uuid.Nil, "", err
		}
		r.logger.Info().Msgf("Inserted new ingredient: %s (UUID: %s)", created.Name, created.Uuid)
		return created.Uuid, qualifier, nil
	}

	created, err := q.CreateIngredient(ctx, db.CreateIngredientParams{
		Uuid:      uuid.New(),
		Name:      strings.TrimSpace(name),
		CreatedAt: now,
		UpdatedAt: now,
	})
	if err != nil {
		return uuid.Nil, "", err
	}
	r.logger.Info().Msgf("Inserted new ingredient: %s (UUID: %s)", created.Name, created.Uuid)
	return created.Uuid, "", nil
}

// ingredientQualifierWords are pure count/measure nouns that never stand alone
// as an ingredient in this book: when a name ENDS with one (optionally
// pluralised), the noun is a qualifier for whatever precedes it. Deliberately
// narrow — "leaf", "stick", "rib", "fillet", "pod", "head" and "stalk" are
// forms, not counts ("lime leaves", "cinnamon stick", "beef ribs" are real
// ingredients), so they resolve per home and any stray spelling gets an alias.
var ingredientQualifierWords = map[string]bool{
	"clove": true, "sprig": true, "bunch": true, "handful": true,
	"knob": true, "slice": true, "wedge": true,
}

// splitIngredientQualifier separates a trailing count qualifier from an
// ingredient name: "garlic cloves" -> ("garlic", "cloves"). Only the final
// whitespace-separated word is considered, and only when the name has at
// least two words — single words ("cloves" alone) are left untouched.
func splitIngredientQualifier(name string) (string, string) {
	trimmed := strings.TrimSpace(name)
	words := strings.Fields(trimmed)
	if len(words) < 2 {
		return trimmed, ""
	}
	last := strings.ToLower(words[len(words)-1])
	if isQualifierWord(last) {
		return strings.TrimSpace(strings.Join(words[:len(words)-1], " ")), last
	}
	return trimmed, ""
}

// isQualifierWord reports whether w is a count qualifier noun in singular or
// plural form.
func isQualifierWord(w string) bool {
	if ingredientQualifierWords[w] {
		return true
	}
	if s := strings.TrimSuffix(w, "s"); ingredientQualifierWords[s] {
		return true
	}
	if s := strings.TrimSuffix(w, "es"); ingredientQualifierWords[s] {
		return true
	}
	return false
}

// resolveUnit is the same idea for units, which were already normalised on
// write — extracted alongside resolveIngredient so the two upsert call sites
// could collapse into one.
func (r *recipeRepository) resolveUnit(ctx context.Context, q *db.Queries, u recipe.Unit, now time.Time) (uuid.NullUUID, error) {
	name := normalizeUnitName(u.Name)
	if name == "" {
		return uuid.NullUUID{}, nil
	}

	// Plural forms are display concerns, not new units: when someone types
	// "cloves" or "tablespoons", prefer the singular whenever it exists —
	// checked first so a stale plural row can't keep winning. The quantity
	// already carries the count.
	if strings.HasSuffix(name, "s") {
		if singular := strings.TrimSuffix(name, "s"); singular != "" {
			singularRow, singularErr := q.GetUnitByName(ctx, singular)
			switch {
			case singularErr == nil:
				return uuidToNullUUID(&singularRow.Uuid), nil
			case !errors.Is(singularErr, sql.ErrNoRows):
				return uuid.NullUUID{}, singularErr
			}
		}
	}

	unitRow, err := q.GetUnitByName(ctx, name)
	if errors.Is(err, sql.ErrNoRows) {
		unitRow, err = q.CreateUnit(ctx, db.CreateUnitParams{
			Uuid:         uuid.New(),
			Name:         name,
			Abbreviation: sql.NullString{String: u.Abbreviation, Valid: u.Abbreviation != ""},
			CreatedAt:    now,
			UpdatedAt:    now,
		})
		if err != nil {
			return uuid.NullUUID{}, err
		}
		r.logger.Info().Msgf("Inserted new unit: %s (UUID: %s)", name, unitRow.Uuid)
	} else if err != nil {
		return uuid.NullUUID{}, err
	}
	return uuidToNullUUID(&unitRow.Uuid), nil
}

// writeRecipeIngredients resolves and links every ingredient on a recipe.
// SaveRecipe and UpdateRecipe carried byte-identical copies of this loop; the
// duplication is how ingredient handling drifted from unit handling in the
// first place, so they share it now.
//
// Rows are keyed by (home, recipe, ingredient, component), matching the table's
// primary key since 00017 — the same ingredient may legitimately appear in two
// components, and only an exact repeat within one component is dropped.
func (r *recipeRepository) writeRecipeIngredients(ctx context.Context, q *db.Queries, recipeID uuid.UUID, recipeName string, ingredients []recipe.RecipeIngredient, now time.Time) error {
	type ingredientKey struct {
		id        uuid.UUID
		component string
	}
	seen := make(map[ingredientKey]bool, len(ingredients))

	for _, ri := range ingredients {
		ingredientID, qualifier, err := r.resolveIngredient(ctx, q, ri.Ingredient.Name, now)
		if err != nil {
			return err
		}

		key := ingredientKey{id: ingredientID, component: ri.Component}
		if seen[key] {
			r.logger.Warn().
				Str("ingredient", ri.Ingredient.Name).
				Str("component", ri.Component).
				Str("recipe", recipeName).
				Msg("Skipping repeated ingredient within the same component")
			continue
		}
		seen[key] = true

		if qualifier != "" && strings.TrimSpace(ri.Unit.Name) == "" {
			// The name carried a count qualifier ("garlic cloves"): that is
			// the unit, and it measures in cloves. resolveUnit stores the
			// singular; preparation is left to the recipe to state.
			ri.Unit.Name = qualifier
		}

		unitID, err := r.resolveUnit(ctx, q, ri.Unit, now)
		if err != nil {
			return err
		}

		if _, err := q.CreateRecipeIngredient(ctx, db.CreateRecipeIngredientParams{
			RecipeID:     recipeID,
			IngredientID: ingredientID,
			UnitID:       unitID,
			Quantity:     sql.NullFloat64{Float64: ri.Quantity, Valid: true},
			Preparation:  sql.NullString{String: ri.Preparation, Valid: ri.Preparation != ""},
			Component:    ri.Component,
			CreatedAt:    now,
			UpdatedAt:    now,
		}); err != nil {
			return err
		}
		r.logger.Info().Msgf("Linked ingredient %s to recipe %s", ri.Ingredient.Name, recipeName)
	}
	return nil
}

func (r *recipeRepository) GetRecipeByID(ctx context.Context, id uuid.UUID) (*recipe.Recipe, error) {
	var out *recipe.Recipe
	err := InHomeTx(ctx, r.sqlDB, func(q *db.Queries) error {
		// Get basic recipe info
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
		out = rec
		return nil
	})
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (r *recipeRepository) ListRecipes(ctx context.Context, limit, offset int, search string, labels []string, sort string) ([]*recipe.Recipe, int, error) {
	var outRecipes []*recipe.Recipe
	var outCount int
	err := InHomeTx(ctx, r.sqlDB, func(q *db.Queries) error {
		// Prepare search parameter
		var searchParam sql.NullString
		if search != "" {
			searchParam = sql.NullString{String: search, Valid: true}
		}

		// If no labels filter is provided, use standard query
		if len(labels) == 0 {
			// Get count first
			count, err := q.CountRecipes(ctx, search)
			if err != nil {
				return err
			}

			// Get recipes with meal plan status
			recipeRows, err := q.ListRecipes(ctx, db.ListRecipesParams{
				Limit:   int32(limit),
				Offset:  int32(offset),
				Column3: search,
				Column4: sort,
			})
			if err != nil {
				return err
			}

			recipes := make([]*recipe.Recipe, len(recipeRows))
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

			outRecipes = recipes
			outCount = int(count)
			return nil
		}

		// Use label filtering query
		// Get count first
		count, err := q.CountRecipesWithLabels(ctx, db.CountRecipesWithLabelsParams{
			Search:    searchParam,
			LabelKeys: labels,
		})
		if err != nil {
			return err
		}

		// Get recipes with meal plan status and label filtering
		recipeRows, err := q.ListRecipesWithMealPlanStatusAndLabels(ctx, db.ListRecipesWithMealPlanStatusAndLabelsParams{
			Search:       searchParam,
			LabelKeys:    labels,
			RecipeLimit:  int32(limit),
			RecipeOffset: int32(offset),
		})
		if err != nil {
			return err
		}

		recipes := make([]*recipe.Recipe, len(recipeRows))
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

		outRecipes = recipes
		outCount = int(count)
		return nil
	})
	if err != nil {
		return nil, 0, err
	}
	return outRecipes, outCount, nil
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
				Name:      ingRow.IngredientName,
				Canonical: ingRow.IngredientCanonicalName,
				IsStaple:  ingRow.IngredientIsStaple,
			},
			Unit: recipe.Unit{
				Name:         ingRow.UnitName.String,
				Abbreviation: ingRow.UnitAbbreviation.String,
			},
			Quantity:    ingRow.Quantity.Float64,
			Preparation: ingRow.Preparation.String,
			Component:   ingRow.Component,
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
			Type: labelRow.Type,
			Name: labelRow.Name,
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

	err := InHomeTx(ctx, r.sqlDB, func(q *db.Queries) error {
		// Reuses the existing photo row when the URL is unchanged, so editing a
		// recipe doesn't drop or duplicate its photo; a nil MainPhoto clears it.
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

		// Update basic recipe fields
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

		// Delete existing step photos, steps, ingredients, and labels
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

		// Re-insert steps
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
					return err
				}
			}
		}

		// Re-insert ingredients and recipe_ingredient
		if err := r.writeRecipeIngredients(ctx, q, recipeID, rec.Name, rec.Ingredients, now); err != nil {
			return err
		}

		// Sweep up anything the re-insert above left unreferenced — an ingredient
		// renamed in the editor would otherwise linger forever. Carried state
		// (staple flag, aliases) pins a row: a spell-check fix must not lose
		// either, or the next save flips salt back onto the shopping list.
		if err := q.DeleteOrphanedIngredients(ctx); err != nil {
			return err
		}

		// Re-insert labels and recipe_label
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
			_, err = q.CreateRecipeLabel(ctx, db.CreateRecipeLabelParams{
				RecipeID:  recipeID,
				LabelID:   labelRow.Uuid,
				CreatedAt: now,
				UpdatedAt: now,
			})
			if err != nil {
				return err
			}
		}

		r.logger.Info().Str("recipe_id", id.String()).Msg("Recipe updated successfully")

		rec.UUID = recipeID
		rec.CreatedAt = updatedRecipe.CreatedAt
		rec.UpdatedAt = now

		return nil
	})
	if err != nil {
		return nil, err
	}

	return &rec, nil
}

func (r *recipeRepository) ArchiveRecipe(ctx context.Context, id uuid.UUID) error {
	now := time.Now()

	return InHomeTx(ctx, r.sqlDB, func(q *db.Queries) error {
		// Archive the recipe (soft delete)
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

	var out *recipe.Recipe
	err := InHomeTx(ctx, r.sqlDB, func(q *db.Queries) error {
		// Restore the recipe
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

		// Build complete recipe object
		result, err := r.buildRecipeFromRows(ctx, q, restoredRecipe.Uuid, restoredRecipe.Name,
			restoredRecipe.Description, restoredRecipe.CookTime, restoredRecipe.PrepTime,
			restoredRecipe.Servings, restoredRecipe.Url, restoredRecipe.CreatedAt,
			restoredRecipe.UpdatedAt, uuid.NullUUID{}, sql.NullString{})

		if err != nil {
			return err
		}

		r.logger.Info().Str("recipe_id", id.String()).Msg("Recipe restored successfully")
		out = result
		return nil
	})
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (r *recipeRepository) ListArchivedRecipes(ctx context.Context, limit, offset int) ([]*recipe.Recipe, int, error) {
	var outRecipes []*recipe.Recipe
	var outCount int
	err := InHomeTx(ctx, r.sqlDB, func(q *db.Queries) error {
		// Get archived recipes
		recipeRows, err := q.GetArchivedRecipes(ctx, db.GetArchivedRecipesParams{
			Limit:  int32(limit),
			Offset: int32(offset),
		})
		if err != nil {
			return err
		}

		// Get total count of archived recipes
		count, err := q.CountArchivedRecipes(ctx)
		if err != nil {
			return err
		}

		recipes := make([]*recipe.Recipe, len(recipeRows))
		for i, row := range recipeRows {
			rec, err := r.buildRecipeFromRows(ctx, q, row.Uuid, row.Name,
				row.Description, row.CookTime, row.PrepTime, row.Servings,
				row.Url, row.CreatedAt, row.UpdatedAt, row.MainPhotoUuid, row.MainPhotoUrl)
			if err != nil {
				return err
			}
			recipes[i] = rec
		}

		outRecipes = recipes
		outCount = int(count)
		return nil
	})
	if err != nil {
		return nil, 0, err
	}
	return outRecipes, outCount, nil
}

func (r *recipeRepository) SetMainPhoto(ctx context.Context, recipeID uuid.UUID, url string) error {
	return InHomeTx(ctx, r.sqlDB, func(q *db.Queries) error {
		now := time.Now()
		photoID := uuid.New()

		if _, err := q.CreatePhoto(ctx, db.CreatePhotoParams{
			Uuid:       photoID,
			Url:        url,
			EntityType: "recipe",
			EntityID:   recipeID,
			CreatedAt:  now,
			UpdatedAt:  now,
		}); err != nil {
			return fmt.Errorf("storing the photo: %w", err)
		}

		if err := q.SetRecipeMainPhoto(ctx, db.SetRecipeMainPhotoParams{
			Uuid:        recipeID,
			MainPhotoID: uuid.NullUUID{UUID: photoID, Valid: true},
			UpdatedAt:   now,
		}); err != nil {
			return fmt.Errorf("pointing the recipe at it: %w", err)
		}

		return nil
	})
}

func (r *recipeRepository) AddToMealPlan(ctx context.Context, recipeID uuid.UUID) error {
	return InHomeTx(ctx, r.sqlDB, func(q *db.Queries) error {
		return q.AddToMealPlan(ctx, recipeID)
	})
}

func (r *recipeRepository) RemoveFromMealPlan(ctx context.Context, recipeID uuid.UUID) error {
	return InHomeTx(ctx, r.sqlDB, func(q *db.Queries) error {
		return q.RemoveFromMealPlan(ctx, recipeID)
	})
}

func (r *recipeRepository) ListMealPlanRecipes(ctx context.Context) ([]*recipe.Recipe, error) {
	var out []*recipe.Recipe
	err := InHomeTx(ctx, r.sqlDB, func(q *db.Queries) error {
		rows, err := q.ListMealPlanRecipes(ctx)
		if err != nil {
			return err
		}

		recipes := make([]*recipe.Recipe, len(rows))
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

		out = recipes
		return nil
	})
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (r *recipeRepository) ListLabels(ctx context.Context) ([]recipe.LabelSummary, error) {
	var out []recipe.LabelSummary
	err := InHomeTx(ctx, r.sqlDB, func(q *db.Queries) error {
		rows, err := q.ListLabels(ctx)
		if err != nil {
			return err
		}
		labels := make([]recipe.LabelSummary, len(rows))
		for i, row := range rows {
			labels[i] = recipe.LabelSummary{
				Type: row.Type,
				Name: row.Name,
				Uses: int(row.Uses),
			}
		}
		out = labels
		return nil
	})
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (r *recipeRepository) ListUnits(ctx context.Context) ([]recipe.Unit, error) {
	var out []recipe.Unit
	err := InHomeTx(ctx, r.sqlDB, func(q *db.Queries) error {
		rows, err := q.ListUnits(ctx)
		if err != nil {
			return err
		}

		units := make([]recipe.Unit, len(rows))
		for i, row := range rows {
			units[i] = recipe.Unit{
				Name:         row.Name,
				Abbreviation: row.Abbreviation.String,
			}
		}
		out = units
		return nil
	})
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (r *recipeRepository) ListIngredients(ctx context.Context) ([]recipe.Ingredient, error) {
	var out []recipe.Ingredient
	err := InHomeTx(ctx, r.sqlDB, func(q *db.Queries) error {
		rows, err := q.ListIngredients(ctx)
		if err != nil {
			return err
		}

		ingredients := make([]recipe.Ingredient, len(rows))
		for i, row := range rows {
			ingredients[i] = recipe.Ingredient{
				Name:      row.Name,
				Canonical: row.CanonicalName,
				IsStaple:  row.IsStaple,
			}
		}
		out = ingredients
		return nil
	})
	if err != nil {
		return nil, err
	}
	return out, nil
}
