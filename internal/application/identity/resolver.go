// Package identity bridges the auth middleware's resolver port to the account
// service. It sits outside infrastructure/auth so that the packages reading a
// home off a request context never pull the account domain in behind it.
package identity

import (
	"context"
	"errors"

	"github.com/google/uuid"

	"github.com/kieranajp/the-bluer-book/internal/domain/account"
	"github.com/kieranajp/the-bluer-book/internal/domain/account/service"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/auth"
)

type provisioningResolver struct {
	svc service.AccountService
}

// NewResolver builds the resolver the middleware runs on: a first sighting of a
// subject provisions its user and home rather than failing the request.
func NewResolver(svc service.AccountService) auth.UserResolver {
	return &provisioningResolver{svc: svc}
}

func (r *provisioningResolver) Resolve(ctx context.Context, caller auth.Caller) (auth.Session, error) {
	user, err := r.svc.ProvisionFromSubject(ctx, account.Identity{
		Subject:     caller.Subject,
		Email:       caller.Email,
		DisplayName: caller.Name,
	})
	if err != nil {
		return auth.Session{}, err
	}

	home, err := r.svc.ResolveActiveHome(ctx, user, caller.Home)
	if err != nil {
		// A named home the caller isn't in returns that specific refusal; any
		// other not-found is a fault, since asking for no home always provisions one.
		if caller.Home != uuid.Nil && errors.Is(err, account.ErrHomeNotFound) {
			return auth.Session{}, auth.ErrHomeForbidden
		}
		return auth.Session{}, err
	}

	return auth.Session{UserID: user.UUID, HomeID: home.UUID}, nil
}
