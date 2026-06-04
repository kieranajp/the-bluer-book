package repository

import (
	"context"

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
	return r.db.AddToPantry(ctx, ingredient)
}

func (r *pantryRepository) RemoveFromPantry(ctx context.Context, ingredient string) error {
	return r.db.RemoveFromPantry(ctx, ingredient)
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
