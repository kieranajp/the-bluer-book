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

// InHomeTx runs fn against the caller's home. It opens a transaction, publishes
// the home as app.home_id, and commits when fn returns nil; any other outcome,
// including a panic, rolls back.
//
// The GUC is transaction-local, so a connection handed back to the pool carries
// nothing: work that forgets this helper reads no tenant rows and writes none,
// because every home_id defaults from that setting and is NOT NULL. That is why
// no query names a home and no caller passes one.
//
// fn's error comes back untouched. Callers still compare against sql.ErrNoRows
// and their own domain errors.
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
