// Package service implements the account operations the auth middleware
// depends on: finding or provisioning the caller, and deciding which home their
// request acts on.
package service

import (
	"context"
	"errors"
	"strings"

	"github.com/kieranajp/the-bluer-book/internal/domain/account"
)

// Service is the door into the account domain.
type Service interface {
	// ProvisionFromSubject returns the user behind a token subject, creating
	// them, a home and their ownership of it the first time that subject is
	// seen.
	ProvisionFromSubject(ctx context.Context, id account.Identity) (account.User, error)

	// ResolveActiveHome returns the home a request acts on: the one the user
	// most recently joined.
	ResolveActiveHome(ctx context.Context, user account.User) (account.Home, error)
}

type accountService struct {
	repo account.Repository

	// founderSubject is the operator's subject. It attaches to the home that
	// already holds the recipes rather than to a fresh one. Empty means nobody
	// gets that treatment.
	founderSubject string
}

func NewAccountService(repo account.Repository, founderSubject string) Service {
	return &accountService{repo: repo, founderSubject: founderSubject}
}

func (s *accountService) ProvisionFromSubject(ctx context.Context, id account.Identity) (account.User, error) {
	if id.Subject == "" {
		return account.User{}, errors.New("account: cannot provision without a subject")
	}

	user, err := s.repo.FindUserBySubject(ctx, id.Subject)
	if err == nil {
		return user, nil
	}
	if !errors.Is(err, account.ErrUserNotFound) {
		return account.User{}, err
	}

	user, _, err = s.repo.ProvisionUser(ctx, id, s.homeTarget(id))
	return user, err
}

func (s *accountService) ResolveActiveHome(ctx context.Context, user account.User) (account.Home, error) {
	home, err := s.repo.FindMostRecentHome(ctx, user.UUID)
	if err == nil {
		return home, nil
	}
	if !errors.Is(err, account.ErrHomeNotFound) {
		return account.Home{}, err
	}

	// A known user with no home has lost their last membership. Give them one
	// back rather than locking them out of their own account.
	id := account.Identity{Subject: user.Subject, Email: user.Email, DisplayName: user.DisplayName}
	_, home, err = s.repo.ProvisionUser(ctx, id, s.homeTarget(id))
	return home, err
}

func (s *accountService) homeTarget(id account.Identity) account.HomeTarget {
	if s.founderSubject != "" && id.Subject == s.founderSubject {
		return account.HomeTarget{ID: account.FounderHomeID}
	}
	return account.HomeTarget{Name: homeName(id.Email)}
}

// homeName builds a name for a new home out of the local part of the caller's
// email. The edge forwards the email claim as an optional header, so an absent
// or unusable one has to leave a home that still reads sensibly.
func homeName(email string) string {
	local, _, hasDomain := strings.Cut(email, "@")
	local = strings.TrimSpace(local)
	if !hasDomain || local == "" {
		return "My Book"
	}
	return local + "'s Book"
}
