package repository

import (
	"context"
	"database/sql"

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

// pantryRepository runs every operation inside InHomeTx so the per-request
// home GUC is set before any pantry / shopping-list query reads it. Both
// underlying tables are under FORCE RLS (see migration 00013), so without
// the GUC the queries return zero rows / NOT NULL-violate inserts.
type pantryRepository struct {
	sqlDB  *sql.DB
	logger logger.Logger
}

func NewPantryRepository(sqlDB *sql.DB, logger logger.Logger) PantryRepository {
	return &pantryRepository{sqlDB: sqlDB, logger: logger}
}

func (r *pantryRepository) inTx(ctx context.Context, fn func(q *db.Queries) error) error {
	return InHomeTx(ctx, r.sqlDB, fn)
}

func (r *pantryRepository) AddToPantry(ctx context.Context, ingredient string) error {
	return r.inTx(ctx, func(q *db.Queries) error {
		return q.AddToPantry(ctx, ingredient)
	})
}

func (r *pantryRepository) RemoveFromPantry(ctx context.Context, ingredient string) error {
	return r.inTx(ctx, func(q *db.Queries) error {
		return q.RemoveFromPantry(ctx, ingredient)
	})
}

func (r *pantryRepository) ListPantry(ctx context.Context) ([]pantry.PantryItem, error) {
	var items []pantry.PantryItem
	err := r.inTx(ctx, func(q *db.Queries) error {
		rows, err := q.ListPantry(ctx)
		if err != nil {
			return err
		}
		items = make([]pantry.PantryItem, len(rows))
		for i, row := range rows {
			items[i] = pantry.PantryItem{
				Ingredient: row.Name,
				AddedAt:    row.AddedAt,
			}
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return items, nil
}

func (r *pantryRepository) ShoppingList(ctx context.Context) ([]string, error) {
	var out []string
	err := r.inTx(ctx, func(q *db.Queries) error {
		rows, err := q.ListMealPlanShortfall(ctx)
		if err != nil {
			return err
		}
		out = rows
		return nil
	})
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (r *pantryRepository) AddCustomShoppingItem(ctx context.Context, name string) error {
	return r.inTx(ctx, func(q *db.Queries) error {
		return q.AddCustomShoppingItem(ctx, name)
	})
}

func (r *pantryRepository) RemoveCustomShoppingItem(ctx context.Context, name string) error {
	return r.inTx(ctx, func(q *db.Queries) error {
		return q.RemoveCustomShoppingItem(ctx, name)
	})
}

func (r *pantryRepository) ListCustomShoppingItems(ctx context.Context) ([]string, error) {
	var out []string
	err := r.inTx(ctx, func(q *db.Queries) error {
		rows, err := q.ListCustomShoppingItems(ctx)
		if err != nil {
			return err
		}
		out = rows
		return nil
	})
	if err != nil {
		return nil, err
	}
	return out, nil
}
