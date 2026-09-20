package identity

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"

	"github.com/kieranajp/the-bluer-book/internal/domain/account"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/auth"
)

type stubService struct {
	seen      account.Identity
	user      account.User
	home      account.Home
	requested uuid.UUID

	provisionErr error
	homeErr      error
	homeAsked    bool
}

func (s *stubService) ProvisionFromSubject(_ context.Context, id account.Identity) (account.User, error) {
	s.seen = id
	return s.user, s.provisionErr
}

func (s *stubService) ResolveActiveHome(_ context.Context, _ account.User, requested uuid.UUID) (account.Home, error) {
	s.homeAsked = true
	s.requested = requested
	return s.home, s.homeErr
}

func (s *stubService) FindUser(context.Context, uuid.UUID) (account.User, error) {
	return s.user, nil
}

func (s *stubService) ListHomes(context.Context, uuid.UUID) ([]account.Membership, error) {
	return nil, nil
}

func (s *stubService) Invite(context.Context, uuid.UUID, uuid.UUID, string, account.Role) (account.Invitation, string, error) {
	return account.Invitation{}, "", nil
}

func (s *stubService) AcceptInvitation(context.Context, uuid.UUID, string) (account.Home, account.Role, error) {
	return account.Home{}, "", nil
}

func (s *stubService) ListMembers(context.Context, uuid.UUID, uuid.UUID) ([]account.Member, error) {
	return nil, nil
}

func (s *stubService) RemoveMember(context.Context, uuid.UUID, uuid.UUID, uuid.UUID) error {
	return nil
}

func TestResolveCarriesTheEdgeClaimsIntoTheDomain(t *testing.T) {
	svc := &stubService{
		user: account.User{UUID: uuid.New()},
		home: account.Home{UUID: uuid.New()},
	}

	session, err := NewResolver(svc).Resolve(context.Background(), auth.Caller{
		Subject: "subject-a",
		Email:   "ada@example.com",
		Name:    "Ada",
	})
	if err != nil {
		t.Fatalf("Resolve: %v", err)
	}

	want := account.Identity{Subject: "subject-a", Email: "ada@example.com", DisplayName: "Ada"}
	if svc.seen != want {
		t.Errorf("service saw %+v, want %+v", svc.seen, want)
	}
	if session.UserID != svc.user.UUID {
		t.Errorf("session user %s, want %s", session.UserID, svc.user.UUID)
	}
	if session.HomeID != svc.home.UUID {
		t.Errorf("session home %s, want %s", session.HomeID, svc.home.UUID)
	}
}

func TestResolveStopsWhenProvisioningFails(t *testing.T) {
	boom := errors.New("connection refused")
	svc := &stubService{provisionErr: boom}

	if _, err := NewResolver(svc).Resolve(context.Background(), auth.Caller{Subject: "subject-a"}); !errors.Is(err, boom) {
		t.Errorf("got error %v, want %v", err, boom)
	}
	if svc.homeAsked {
		t.Error("asked for a home for a user that was never provisioned")
	}
}

func TestResolveFailsWhenNoHomeCanBeFound(t *testing.T) {
	boom := errors.New("connection refused")
	svc := &stubService{user: account.User{UUID: uuid.New()}, homeErr: boom}

	session, err := NewResolver(svc).Resolve(context.Background(), auth.Caller{Subject: "subject-a"})
	if !errors.Is(err, boom) {
		t.Errorf("got error %v, want %v", err, boom)
	}
	if session != (auth.Session{}) {
		t.Errorf("returned session %+v alongside an error", session)
	}
}

// caller.Home is a request, not a fact, so it must reach the service exactly
// as the edge asserted it — the resolver proves nothing about it itself.
func TestResolveHomeRequestIsPassedThroughUnchanged(t *testing.T) {
	requested := uuid.New()
	svc := &stubService{user: account.User{UUID: uuid.New()}, home: account.Home{UUID: uuid.New()}}

	if _, err := NewResolver(svc).Resolve(context.Background(), auth.Caller{Subject: "subject-a", Home: requested}); err != nil {
		t.Fatalf("Resolve: %v", err)
	}
	if svc.requested != requested {
		t.Errorf("service was asked to resolve home %s, want %s", svc.requested, requested)
	}
}

func TestResolveTurnsHomeNotFoundIntoForbiddenWhenAHomeWasRequested(t *testing.T) {
	svc := &stubService{user: account.User{UUID: uuid.New()}, homeErr: account.ErrHomeNotFound}

	_, err := NewResolver(svc).Resolve(context.Background(), auth.Caller{Subject: "subject-a", Home: uuid.New()})
	if !errors.Is(err, auth.ErrHomeForbidden) {
		t.Errorf("got error %v, want %v", err, auth.ErrHomeForbidden)
	}
}

// With no home requested, ErrHomeNotFound means a known user lost their last
// membership — a genuine fault, not a caller naming somebody else's home —
// so it must reach the caller unchanged rather than becoming ErrHomeForbidden.
func TestResolveLeavesHomeNotFoundUnchangedWhenNoHomeWasRequested(t *testing.T) {
	svc := &stubService{user: account.User{UUID: uuid.New()}, homeErr: account.ErrHomeNotFound}

	_, err := NewResolver(svc).Resolve(context.Background(), auth.Caller{Subject: "subject-a"})
	if !errors.Is(err, account.ErrHomeNotFound) {
		t.Errorf("got error %v, want %v", err, account.ErrHomeNotFound)
	}
	if errors.Is(err, auth.ErrHomeForbidden) {
		t.Error("no home was requested, yet the error became ErrHomeForbidden")
	}
}
