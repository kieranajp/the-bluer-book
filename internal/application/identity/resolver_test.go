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
	seen account.Identity
	user account.User
	home account.Home

	provisionErr error
	homeErr      error
	homeAsked    bool
}

func (s *stubService) ProvisionFromSubject(_ context.Context, id account.Identity) (account.User, error) {
	s.seen = id
	return s.user, s.provisionErr
}

func (s *stubService) ResolveActiveHome(_ context.Context, _ account.User) (account.Home, error) {
	s.homeAsked = true
	return s.home, s.homeErr
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
