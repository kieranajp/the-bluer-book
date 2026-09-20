// Package auth turns the identity the edge asserts about a request into
// per-request context: who is calling, and which home the request acts on. The
// repository layer reads the home back out to scope every database touch.
package auth

import (
	"context"
	"errors"

	"github.com/google/uuid"
)

// ErrNoHome means a request context carries no home — the middleware was not in
// the chain, or the path never established one. Callers fail closed on it
// rather than reaching for a default.
var ErrNoHome = errors.New("auth: no home in context")

// Caller is what the edge asserts about a request. Only Subject is guaranteed;
// Email and Name arrive only while the edge forwards those claims, so nothing
// may depend on them being there.
type Caller struct {
	Subject string
	Email   string
	Name    string
}

// Session is a Caller resolved onto the rows this application owns.
type Session struct {
	UserID uuid.UUID
	HomeID uuid.UUID
}

// UserResolver maps an asserted caller onto their user and active home,
// provisioning both the first time a subject is seen. The implementation lives
// in application/identity so that packages reading a home off a context do not
// pull the account domain in behind it.
type UserResolver interface {
	Resolve(ctx context.Context, caller Caller) (Session, error)
}

type ctxKey int

const (
	userIDKey ctxKey = iota
	homeIDKey
)

// WithIdentity stamps the calling user and their active home onto a context.
func WithIdentity(ctx context.Context, userID, homeID uuid.UUID) context.Context {
	return context.WithValue(WithHome(ctx, homeID), userIDKey, userID)
}

// WithHome stamps a home with no user behind it, for work that acts on a home
// without anybody having asked: the MCP server serves one fixed home and has no
// caller.
func WithHome(ctx context.Context, homeID uuid.UUID) context.Context {
	return context.WithValue(ctx, homeIDKey, homeID)
}

// HomeID returns the home the request acts on. A false second return means the
// request never went through the middleware.
func HomeID(ctx context.Context) (uuid.UUID, bool) {
	id, ok := ctx.Value(homeIDKey).(uuid.UUID)
	return id, ok
}

// UserID returns the calling user.
func UserID(ctx context.Context) (uuid.UUID, bool) {
	id, ok := ctx.Value(userIDKey).(uuid.UUID)
	return id, ok
}
