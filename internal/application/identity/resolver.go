// Package identity bridges the auth middleware's UserResolver port to
// the account-domain service. It lives outside the auth package so
// that downstream consumers of auth (the repository layer's InHomeTx,
// the chat handler, the MCP bridge) don't pull in the account service
// transitively — which would loop right back through the recipe and
// pantry services the account service needs for the data-export path.
package identity

import (
	"context"
	"errors"

	"github.com/google/uuid"

	"github.com/kieranajp/the-bluer-book/internal/domain/account"
	"github.com/kieranajp/the-bluer-book/internal/domain/account/service"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/auth"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/storage/db"
)

// provisioningResolver bridges the auth middleware to the account
// service. On miss it provisions a user + home rather than 401-ing, so
// every authenticated request from a known IdP lands the caller in some
// home of theirs.
type provisioningResolver struct {
	svc service.Service
}

// NewResolver builds the production UserResolver — provision-on-first-
// login backed by the account service.
func NewResolver(svc service.Service) auth.UserResolver {
	return &provisioningResolver{svc: svc}
}

func (r *provisioningResolver) Resolve(ctx context.Context, subject string, requestedHomeID *uuid.UUID) (db.User, db.Home, error) {
	user, home, err := r.svc.ProvisionFromSubject(ctx, subject)
	if err != nil {
		return db.User{}, db.Home{}, err
	}

	// If the client requested a specific home, switch to it (must be a
	// home they belong to).
	if requestedHomeID != nil && *requestedHomeID != home.UUID {
		switched, err := r.svc.ResolveActiveHome(ctx, user.UUID, requestedHomeID)
		if err != nil {
			if errors.Is(err, account.ErrHomeNotFound) {
				return db.User{}, db.Home{}, auth.ErrNoMembership
			}
			return db.User{}, db.Home{}, err
		}
		home = switched
	}

	return toDBUser(user), toDBHome(home), nil
}

func toDBUser(u *account.User) db.User {
	out := db.User{
		Uuid:      u.UUID,
		Subject:   u.Subject,
		CreatedAt: u.CreatedAt,
		UpdatedAt: u.UpdatedAt,
	}
	if u.Email != "" {
		out.Email.String = u.Email
		out.Email.Valid = true
	}
	if u.DisplayName != "" {
		out.DisplayName.String = u.DisplayName
		out.DisplayName.Valid = true
	}
	return out
}

func toDBHome(h *account.Home) db.Home {
	return db.Home{
		Uuid:      h.UUID,
		Name:      h.Name,
		CreatedAt: h.CreatedAt,
		UpdatedAt: h.UpdatedAt,
	}
}
