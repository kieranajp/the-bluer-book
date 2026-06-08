package repository

import (
	"context"
	"database/sql"

	"github.com/kieranajp/the-bluer-book/internal/infrastructure/auth"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/storage/db"
)

// InHomeTx opens a transaction, sets the per-request app.home_id GUC, and
// runs fn with a tx-bound *db.Queries. It commits on a nil error, rolls
// back on a non-nil error or panic. The GUC is set with SET LOCAL so it
// is scoped to the transaction — pooled-connection reuse cannot leak it.
//
// Every operation touching a tenant table runs through this helper: the
// generated queries pull home_id from current_setting('app.home_id', ...)
// in both predicates and INSERT VALUE lists, so without a tx-scoped GUC
// they fail closed (SELECT returns 0 rows, INSERT violates NOT NULL).
func InHomeTx(ctx context.Context, sqlDB *sql.DB, fn func(q *db.Queries) error) error {
	homeID, ok := auth.HomeID(ctx)
	if !ok {
		return auth.ErrNoHome
	}

	tx, err := sqlDB.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	committed := false
	defer func() {
		if !committed {
			_ = tx.Rollback()
		}
	}()

	if _, err := tx.ExecContext(ctx, "SELECT set_config('app.home_id', $1, true)", homeID.String()); err != nil {
		return err
	}

	if err := fn(db.New(tx)); err != nil {
		return err
	}

	if err := tx.Commit(); err != nil {
		return err
	}
	committed = true
	return nil
}
