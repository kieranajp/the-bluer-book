package repository

import (
	"context"
	"database/sql"
	"fmt"

	"github.com/google/uuid"

	"github.com/kieranajp/the-bluer-book/internal/infrastructure/auth"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/metrics"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/storage/db"
)

// InHomeTx scopes fn to the caller's home via the app.home_id GUC, rolling back on panic as well as error.
// Bypassing it writes nothing: home_id defaults from that GUC and is NOT NULL.
func InHomeTx(ctx context.Context, sqlDB *sql.DB, fn func(q *db.Queries) error) error {
	homeID, ok := auth.HomeID(ctx)
	if !ok || homeID == uuid.Nil {
		return auth.ErrNoHome
	}

	tx, err := sqlDB.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("begin home transaction: %w", err)
	}

	committed := false
	defer func() {
		if !committed {
			_ = tx.Rollback()
		}
	}()

	if _, err := tx.ExecContext(ctx, "SELECT set_config('app.home_id', $1, true)", homeID.String()); err != nil {
		return fmt.Errorf("set app.home_id: %w", err)
	}

	if err := fn(db.New(metrics.NewInstrumentedDBTX(tx))); err != nil {
		return err
	}

	if err := tx.Commit(); err != nil {
		return fmt.Errorf("commit home transaction: %w", err)
	}
	committed = true
	return nil
}
