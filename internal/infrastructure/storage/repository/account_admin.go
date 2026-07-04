package repository

import (
	"context"
	"database/sql"

	"github.com/google/uuid"

	"github.com/kieranajp/the-bluer-book/internal/domain/account"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/storage/db"
)

// accountAdminRepository runs destructive deletes on an owner-role
// connection: under FORCE RLS the app role can't reliably cascade
// across home_id, and the deletion flow must work even when the user's
// active home GUC isn't set to the home being purged. Wire this only
// to the owner sql.DB (cfg.DBDSN), never to the app-role pool.
type accountAdminRepository struct {
	q *db.Queries
}

func NewAccountAdminRepository(ownerDB *sql.DB) account.AdminRepository {
	return &accountAdminRepository{q: db.New(ownerDB)}
}

func (r *accountAdminRepository) PurgeHome(ctx context.Context, homeID uuid.UUID) error {
	return r.q.PurgeHome(ctx, homeID)
}

func (r *accountAdminRepository) DeleteUser(ctx context.Context, userID uuid.UUID) error {
	return r.q.DeleteUser(ctx, userID)
}
