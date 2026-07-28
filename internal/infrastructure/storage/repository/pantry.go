package repository

import (
	"context"
	"database/sql"
	"errors"

	"github.com/google/uuid"
	"github.com/kieranajp/the-bluer-book/internal/domain/pantry"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/storage/db"
)

type PantryRepository interface {
	AddToPantry(ctx context.Context, ingredient string) error
	RemoveFromPantry(ctx context.Context, ingredient string) error
	ListPantry(ctx context.Context) ([]pantry.PantryItem, error)
	ShoppingList(ctx context.Context) ([]string, error)

	// Custom (free-text) shopping list items, kept separate from the
	// meal-plan-derived shortfall.
	AddCustomShoppingItem(ctx context.Context, name string) error
	RemoveCustomShoppingItem(ctx context.Context, name string) error
	ListCustomShoppingItems(ctx context.Context) ([]string, error)
}

type pantryRepository struct {
	db     *db.Queries
	logger logger.Logger
}

func NewPantryRepository(db *db.Queries, logger logger.Logger) PantryRepository {
	return &pantryRepository{db: db, logger: logger}
}

func (r *pantryRepository) AddToPantry(ctx context.Context, ingredient string) error {
	id, err := r.resolveIngredient(ctx, ingredient)
	if err != nil {
		return err
	}
	return r.db.AddToPantry(ctx, id)
}

func (r *pantryRepository) RemoveFromPantry(ctx context.Context, ingredient string) error {
	// Resolve first purely to validate the name: an unknown ingredient is worth
	// reporting rather than passing off as a successful removal. The delete
	// itself works by name so it clears every casing variant.
	if _, err := r.resolveIngredient(ctx, ingredient); err != nil {
		return err
	}
	return r.db.RemoveFromPantry(ctx, ingredient)
}

// resolveIngredient maps a free-text ingredient name onto a known ingredient,
// tolerating casing and surrounding whitespace. A name that matches nothing is
// an error: pantry entries are foreign keys into the ingredients table, so
// there is no row to create, and reporting success would leave the caller
// believing the pantry changed when it didn't.
func (r *pantryRepository) resolveIngredient(ctx context.Context, name string) (uuid.UUID, error) {
	row, err := r.db.FindIngredientByName(ctx, name)
	if errors.Is(err, sql.ErrNoRows) {
		return uuid.Nil, pantry.IngredientNotFoundError{Name: name}
	}
	if err != nil {
		return uuid.Nil, err
	}
	return row.Uuid, nil
}

func (r *pantryRepository) ListPantry(ctx context.Context) ([]pantry.PantryItem, error) {
	rows, err := r.db.ListPantry(ctx)
	if err != nil {
		return nil, err
	}

	items := make([]pantry.PantryItem, len(rows))
	for i, row := range rows {
		items[i] = pantry.PantryItem{
			Ingredient: row.Name,
			AddedAt:    row.AddedAt,
		}
	}
	return items, nil
}

func (r *pantryRepository) ShoppingList(ctx context.Context) ([]string, error) {
	return r.db.ListMealPlanShortfall(ctx)
}

func (r *pantryRepository) AddCustomShoppingItem(ctx context.Context, name string) error {
	return r.db.AddCustomShoppingItem(ctx, name)
}

func (r *pantryRepository) RemoveCustomShoppingItem(ctx context.Context, name string) error {
	return r.db.RemoveCustomShoppingItem(ctx, name)
}

func (r *pantryRepository) ListCustomShoppingItems(ctx context.Context) ([]string, error) {
	return r.db.ListCustomShoppingItems(ctx)
}
