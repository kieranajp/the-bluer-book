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

	// SetStaple marks an ingredient as always-in-the-cupboard, keeping it off
	// the shopping list and treating it as present for "what can I cook".
	SetStaple(ctx context.Context, ingredient string, staple bool) error

	// Custom (free-text) shopping list items, kept separate from the
	// meal-plan-derived shortfall.
	AddCustomShoppingItem(ctx context.Context, name string) error
	RemoveCustomShoppingItem(ctx context.Context, name string) error
	ListCustomShoppingItems(ctx context.Context) ([]string, error)
}

type pantryRepository struct {
	sqlDB  *sql.DB
	logger logger.Logger
}

func NewPantryRepository(sqlDB *sql.DB, logger logger.Logger) PantryRepository {
	return &pantryRepository{sqlDB: sqlDB, logger: logger}
}

func (r *pantryRepository) AddToPantry(ctx context.Context, ingredient string) error {
	return InHomeTx(ctx, r.sqlDB, func(q *db.Queries) error {
		id, err := r.resolveIngredient(ctx, q, ingredient)
		if err != nil {
			return err
		}
		return q.AddToPantry(ctx, id)
	})
}

func (r *pantryRepository) RemoveFromPantry(ctx context.Context, ingredient string) error {
	return InHomeTx(ctx, r.sqlDB, func(q *db.Queries) error {
		id, err := r.resolveIngredient(ctx, q, ingredient)
		if err != nil {
			return err
		}
		return q.RemoveFromPantry(ctx, id)
	})
}

// SetStaple marks an ingredient as always-in-the-cupboard, keeping it off the
// shopping list and treating it as present for "what can I cook".
func (r *pantryRepository) SetStaple(ctx context.Context, ingredient string, staple bool) error {
	return InHomeTx(ctx, r.sqlDB, func(q *db.Queries) error {
		id, err := r.resolveIngredient(ctx, q, ingredient)
		if err != nil {
			return err
		}
		return q.SetIngredientStaple(ctx, db.SetIngredientStapleParams{Uuid: id, IsStaple: staple})
	})
}

// resolveIngredient maps a free-text ingredient name onto a known ingredient,
// via canonical name and then the alias table. A name that matches nothing is
// an error: pantry entries are foreign keys into the ingredients table, so
// there is no row to create, and reporting success would leave the caller
// believing the pantry changed when it didn't.
func (r *pantryRepository) resolveIngredient(ctx context.Context, q *db.Queries, name string) (uuid.UUID, error) {
	row, err := q.FindIngredientByName(ctx, name)
	if errors.Is(err, sql.ErrNoRows) {
		return uuid.Nil, pantry.IngredientNotFoundError{Name: name}
	}
	if err != nil {
		return uuid.Nil, err
	}
	return row.Uuid, nil
}

func (r *pantryRepository) ListPantry(ctx context.Context) ([]pantry.PantryItem, error) {
	var items []pantry.PantryItem
	err := InHomeTx(ctx, r.sqlDB, func(q *db.Queries) error {
		rows, err := q.ListPantry(ctx)
		if err != nil {
			return err
		}

		items = make([]pantry.PantryItem, len(rows))
		for i, row := range rows {
			items[i] = pantry.PantryItem{
				Ingredient: row.Name,
				Canonical:  row.CanonicalName,
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
	var list []string
	err := InHomeTx(ctx, r.sqlDB, func(q *db.Queries) error {
		var err error
		list, err = q.ListMealPlanShortfall(ctx)
		return err
	})
	if err != nil {
		return nil, err
	}
	return list, nil
}

func (r *pantryRepository) AddCustomShoppingItem(ctx context.Context, name string) error {
	return InHomeTx(ctx, r.sqlDB, func(q *db.Queries) error {
		return q.AddCustomShoppingItem(ctx, name)
	})
}

func (r *pantryRepository) RemoveCustomShoppingItem(ctx context.Context, name string) error {
	return InHomeTx(ctx, r.sqlDB, func(q *db.Queries) error {
		return q.RemoveCustomShoppingItem(ctx, name)
	})
}

func (r *pantryRepository) ListCustomShoppingItems(ctx context.Context) ([]string, error) {
	var list []string
	err := InHomeTx(ctx, r.sqlDB, func(q *db.Queries) error {
		var err error
		list, err = q.ListCustomShoppingItems(ctx)
		return err
	})
	if err != nil {
		return nil, err
	}
	return list, nil
}
