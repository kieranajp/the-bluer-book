package service

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"

	"github.com/kieranajp/the-bluer-book/internal/domain/account"
)

type stubRepo struct {
	user account.User
	home account.Home

	userErr error
	homeErr error

	provisioned    []account.Identity
	provisionedAt  []account.HomeTarget
	provisionError error
}

func (s *stubRepo) FindUserBySubject(context.Context, string) (account.User, error) {
	if s.userErr != nil {
		return account.User{}, s.userErr
	}
	return s.user, nil
}

func (s *stubRepo) FindMostRecentHome(context.Context, uuid.UUID) (account.Home, error) {
	if s.homeErr != nil {
		return account.Home{}, s.homeErr
	}
	return s.home, nil
}

func (s *stubRepo) ProvisionUser(_ context.Context, id account.Identity, target account.HomeTarget) (account.User, account.Home, error) {
	s.provisioned = append(s.provisioned, id)
	s.provisionedAt = append(s.provisionedAt, target)
	if s.provisionError != nil {
		return account.User{}, account.Home{}, s.provisionError
	}
	home := account.Home{UUID: target.ID, Name: target.Name}
	if home.UUID == uuid.Nil {
		home.UUID = uuid.New()
	}
	return account.User{UUID: uuid.New(), Subject: id.Subject, Email: id.Email}, home, nil
}

func TestProvisionFromSubjectCreatesUserAndHomeOnFirstSight(t *testing.T) {
	repo := &stubRepo{userErr: account.ErrUserNotFound}
	svc := NewAccountService(repo, "")

	user, err := svc.ProvisionFromSubject(context.Background(), account.Identity{
		Subject: "subject-a",
		Email:   "ada@example.com",
	})
	if err != nil {
		t.Fatalf("ProvisionFromSubject: %v", err)
	}
	if user.Subject != "subject-a" {
		t.Errorf("provisioned user has subject %q, want subject-a", user.Subject)
	}
	if len(repo.provisioned) != 1 {
		t.Fatalf("provisioned %d times, want 1", len(repo.provisioned))
	}
	if got := repo.provisionedAt[0]; got.ID != uuid.Nil {
		t.Errorf("provisioned into home %s, want a newly created one", got.ID)
	}
}

func TestProvisionFromSubjectLeavesAKnownUserAlone(t *testing.T) {
	known := account.User{UUID: uuid.New(), Subject: "subject-a"}
	repo := &stubRepo{user: known}
	svc := NewAccountService(repo, "")

	user, err := svc.ProvisionFromSubject(context.Background(), account.Identity{Subject: "subject-a"})
	if err != nil {
		t.Fatalf("ProvisionFromSubject: %v", err)
	}
	if user.UUID != known.UUID {
		t.Errorf("returned user %s, want the known %s", user.UUID, known.UUID)
	}
	if len(repo.provisioned) != 0 {
		t.Errorf("provisioned a user that already existed")
	}
}

func TestFounderSubjectAttachesToTheFounderHome(t *testing.T) {
	repo := &stubRepo{userErr: account.ErrUserNotFound}
	svc := NewAccountService(repo, "founder-subject")

	if _, err := svc.ProvisionFromSubject(context.Background(), account.Identity{
		Subject: "founder-subject",
		Email:   "kieran@example.com",
	}); err != nil {
		t.Fatalf("ProvisionFromSubject: %v", err)
	}

	if got := repo.provisionedAt[0].ID; got != account.FounderHomeID {
		t.Errorf("founder landed in home %s, want %s", got, account.FounderHomeID)
	}
}

func TestOtherSubjectsDoNotTakeTheFounderHome(t *testing.T) {
	repo := &stubRepo{userErr: account.ErrUserNotFound}
	svc := NewAccountService(repo, "founder-subject")

	if _, err := svc.ProvisionFromSubject(context.Background(), account.Identity{
		Subject: "someone-else",
		Email:   "ada@example.com",
	}); err != nil {
		t.Fatalf("ProvisionFromSubject: %v", err)
	}

	if got := repo.provisionedAt[0].ID; got != uuid.Nil {
		t.Errorf("provisioned into home %s, want a newly created one", got)
	}
}

func TestNewHomeIsNamedAfterTheEmailLocalPart(t *testing.T) {
	cases := map[string]struct {
		email string
		want  string
	}{
		"local part":      {email: "ada@example.com", want: "ada's Book"},
		"no email at all": {email: "", want: "My Book"},
		"not an email":    {email: "ada", want: "My Book"},
		"empty local":     {email: "@example.com", want: "My Book"},
	}

	for name, tc := range cases {
		t.Run(name, func(t *testing.T) {
			repo := &stubRepo{userErr: account.ErrUserNotFound}
			svc := NewAccountService(repo, "")

			if _, err := svc.ProvisionFromSubject(context.Background(), account.Identity{
				Subject: "subject-a",
				Email:   tc.email,
			}); err != nil {
				t.Fatalf("ProvisionFromSubject: %v", err)
			}

			if got := repo.provisionedAt[0].Name; got != tc.want {
				t.Errorf("home named %q, want %q", got, tc.want)
			}
		})
	}
}

func TestResolveActiveHomeReturnsTheMostRecentOne(t *testing.T) {
	home := account.Home{UUID: uuid.New(), Name: "Founder"}
	repo := &stubRepo{home: home}
	svc := NewAccountService(repo, "")

	got, err := svc.ResolveActiveHome(context.Background(), account.User{UUID: uuid.New()})
	if err != nil {
		t.Fatalf("ResolveActiveHome: %v", err)
	}
	if got.UUID != home.UUID {
		t.Errorf("resolved home %s, want %s", got.UUID, home.UUID)
	}
}

func TestResolveActiveHomeGivesAHomelessUserOneBack(t *testing.T) {
	repo := &stubRepo{homeErr: account.ErrHomeNotFound}
	svc := NewAccountService(repo, "")

	got, err := svc.ResolveActiveHome(context.Background(), account.User{
		UUID:    uuid.New(),
		Subject: "subject-a",
		Email:   "ada@example.com",
	})
	if err != nil {
		t.Fatalf("ResolveActiveHome: %v", err)
	}
	if got.Name != "ada's Book" {
		t.Errorf("replacement home named %q, want ada's Book", got.Name)
	}
	if len(repo.provisioned) != 1 {
		t.Fatalf("provisioned %d times, want 1", len(repo.provisioned))
	}
}

func TestResolveActiveHomeSurfacesLookupFailures(t *testing.T) {
	boom := errors.New("connection refused")
	repo := &stubRepo{homeErr: boom}
	svc := NewAccountService(repo, "")

	if _, err := svc.ResolveActiveHome(context.Background(), account.User{UUID: uuid.New()}); !errors.Is(err, boom) {
		t.Errorf("got error %v, want %v", err, boom)
	}
	if len(repo.provisioned) != 0 {
		t.Errorf("provisioned a home after a failed lookup")
	}
}
