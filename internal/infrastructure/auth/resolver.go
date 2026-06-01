package auth

import (
	"context"
	"database/sql"
	"errors"

	"github.com/google/uuid"

	"github.com/kieranajp/the-bluer-book/internal/infrastructure/storage/db"
)

// dbResolver is the Phase 2 implementation of UserResolver: it errors on
// miss rather than provisioning. Phase 3 replaces it with one that
// auto-creates a user + home on first login.
type dbResolver struct {
	q *db.Queries
}

// NewResolver builds a UserResolver backed by the accounts queries.
// Reads run on the pool (no per-request tx needed — these tables aren't
// under RLS).
func NewResolver(q *db.Queries) UserResolver {
	return &dbResolver{q: q}
}

func (r *dbResolver) Resolve(ctx context.Context, subject string, requestedHomeID *uuid.UUID) (db.User, db.Home, error) {
	user, err := r.q.GetUserBySubject(ctx, subject)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return db.User{}, db.Home{}, ErrUnknownSubject
		}
		return db.User{}, db.Home{}, err
	}

	var home db.Home
	if requestedHomeID != nil {
		home, err = r.q.GetHomeForUserByID(ctx, db.GetHomeForUserByIDParams{
			UserID: user.Uuid,
			Uuid:   *requestedHomeID,
		})
		if err != nil {
			if errors.Is(err, sql.ErrNoRows) {
				return db.User{}, db.Home{}, ErrNoMembership
			}
			return db.User{}, db.Home{}, err
		}
		return user, home, nil
	}

	home, err = r.q.GetMostRecentHomeForUser(ctx, user.Uuid)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return db.User{}, db.Home{}, ErrNoMembership
		}
		return db.User{}, db.Home{}, err
	}
	return user, home, nil
}
