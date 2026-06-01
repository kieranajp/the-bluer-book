// Package auth wires the X-User edge header through to per-request
// context values (user id + active home id) that the repository layer
// reads in inHomeTx to scope every database operation.
package auth

import (
	"context"
	"errors"

	"github.com/google/uuid"

	"github.com/kieranajp/the-bluer-book/internal/infrastructure/storage/db"
)

// ErrUnknownSubject is returned by UserResolver.Resolve when the supplied
// subject (Kratos identity id from X-User) has no matching user row. In
// Phase 2 this is terminal — 401. Phase 3 will replace the impl with one
// that provisions a user + home on miss instead of erroring.
var ErrUnknownSubject = errors.New("auth: unknown subject")

// ErrNoMembership means the user exists but has no active home — e.g.
// every membership was deleted. Treated as 401 by the middleware.
var ErrNoMembership = errors.New("auth: user has no home membership")

// ErrNoHome is returned by repository layer helpers when the request
// context carries no home id (i.e. the auth middleware was not in the
// chain, or it ran on a path that doesn't require authentication).
var ErrNoHome = errors.New("auth: no home in context")

// UserResolver maps an edge-supplied subject to a (user, active home)
// pair. The impl in this package looks up an existing row and errors on
// miss; the Phase 3 impl will additionally provision.
type UserResolver interface {
	Resolve(ctx context.Context, subject string, requestedHomeID *uuid.UUID) (db.User, db.Home, error)
}

type ctxKey int

const (
	userIDKey ctxKey = iota
	homeIDKey
)

// WithIdentity stamps the user id and home id into the context.
func WithIdentity(ctx context.Context, userID, homeID uuid.UUID) context.Context {
	ctx = context.WithValue(ctx, userIDKey, userID)
	ctx = context.WithValue(ctx, homeIDKey, homeID)
	return ctx
}

// HomeID returns the active home id from context. The bool reports whether
// it was set — a false return means an unauthenticated request, and the
// caller (typically a repo helper) should fail closed.
func HomeID(ctx context.Context) (uuid.UUID, bool) {
	id, ok := ctx.Value(homeIDKey).(uuid.UUID)
	return id, ok
}

// UserID returns the authenticated user id from context.
func UserID(ctx context.Context) (uuid.UUID, bool) {
	id, ok := ctx.Value(userIDKey).(uuid.UUID)
	return id, ok
}
