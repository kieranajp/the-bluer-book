// Package auth turns the identity the edge asserts about a request into
// per-request context: who is calling, and which home the request acts on.
package auth

import (
	"context"
	"errors"

	"github.com/google/uuid"
)

// ErrNoHome means a request context carries no home; callers fail closed
// rather than falling back to a default.
var ErrNoHome = errors.New("auth: no home in context")

// ErrHomeForbidden means the caller named a home they are not a member of.
var ErrHomeForbidden = errors.New("auth: caller is not a member of the requested home")

// Caller is what the edge asserts about a request. Only Subject is
// guaranteed; Email and Name may be empty.
type Caller struct {
	Subject string
	Email   string
	Name    string

	// Home is client-asserted, not verified; uuid.Nil means none was asked for.
	Home uuid.UUID
}

// Session is a Caller resolved onto the rows this application owns.
type Session struct {
	UserID uuid.UUID
	HomeID uuid.UUID
}

// UserResolver maps an asserted caller onto their user and active home,
// provisioning both the first time a subject is seen.
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

// WithHome stamps a home with no user behind it, for callerless work like
// the MCP server, which serves one fixed home.
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
