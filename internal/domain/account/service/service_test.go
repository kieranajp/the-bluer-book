package service

import (
	"context"
	"encoding/base64"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/kieranajp/the-bluer-book/internal/domain/account"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/metrics"
)

type findHomeForUserCall struct {
	userID, homeID uuid.UUID
}

type findRoleCall struct {
	homeID, userID uuid.UUID
}

type createInvitationCall struct {
	inv  account.Invitation
	hash string
}

type redeemInvitationCall struct {
	hash   string
	userID uuid.UUID
}

type removeMemberCall struct {
	homeID, userID uuid.UUID
}

type stubRepo struct {
	user account.User
	home account.Home

	userErr error
	homeErr error

	lookedUp       []string
	provisioned    []account.Identity
	provisionedAt  []account.HomeTarget
	provisionError error

	refreshed      []account.Identity
	refreshedUser  account.User
	refreshProfErr error

	// findMostRecentHomeCalls only counts calls: a test asserting the
	// fallback never ran does not otherwise care what it would have
	// returned.
	findMostRecentHomeCalls int

	findHomeForUserCalls []findHomeForUserCall
	findHomeForUserHome  account.Home
	findHomeForUserErr   error

	listHomesForUserCalls []uuid.UUID
	listedHomes           []account.Membership
	listHomesForUserErr   error

	findRoleCalls []findRoleCall
	role          account.Role
	roleErr       error

	listMembersCalls []uuid.UUID
	membersList      []account.Member
	listMembersErr   error

	createInvitationCalls []createInvitationCall
	createInvitationErr   error

	redeemInvitationCalls []redeemInvitationCall
	redeemHome            account.Home
	redeemRole            account.Role
	redeemErr             error

	removeMemberCalls []removeMemberCall
	removeMemberErr   error
}

func (s *stubRepo) FindUserBySubject(_ context.Context, subject string) (account.User, error) {
	s.lookedUp = append(s.lookedUp, subject)
	if s.userErr != nil {
		return account.User{}, s.userErr
	}
	return s.user, nil
}

func (s *stubRepo) FindUserByID(context.Context, uuid.UUID) (account.User, error) {
	if s.userErr != nil {
		return account.User{}, s.userErr
	}
	return s.user, nil
}

func (s *stubRepo) FindMostRecentHome(context.Context, uuid.UUID) (account.Home, error) {
	s.findMostRecentHomeCalls++
	if s.homeErr != nil {
		return account.Home{}, s.homeErr
	}
	return s.home, nil
}

func (s *stubRepo) FindHomeForUser(_ context.Context, userID, homeID uuid.UUID) (account.Home, error) {
	s.findHomeForUserCalls = append(s.findHomeForUserCalls, findHomeForUserCall{userID: userID, homeID: homeID})
	if s.findHomeForUserErr != nil {
		return account.Home{}, s.findHomeForUserErr
	}
	return s.findHomeForUserHome, nil
}

func (s *stubRepo) ListHomesForUser(_ context.Context, userID uuid.UUID) ([]account.Membership, error) {
	s.listHomesForUserCalls = append(s.listHomesForUserCalls, userID)
	if s.listHomesForUserErr != nil {
		return nil, s.listHomesForUserErr
	}
	return s.listedHomes, nil
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

func (s *stubRepo) RefreshProfile(_ context.Context, id account.Identity) (account.User, error) {
	s.refreshed = append(s.refreshed, id)
	if s.refreshProfErr != nil {
		return account.User{}, s.refreshProfErr
	}
	return s.refreshedUser, nil
}

func (s *stubRepo) FindRole(_ context.Context, homeID, userID uuid.UUID) (account.Role, error) {
	s.findRoleCalls = append(s.findRoleCalls, findRoleCall{homeID: homeID, userID: userID})
	if s.roleErr != nil {
		return "", s.roleErr
	}
	return s.role, nil
}

func (s *stubRepo) ListMembers(_ context.Context, homeID uuid.UUID) ([]account.Member, error) {
	s.listMembersCalls = append(s.listMembersCalls, homeID)
	if s.listMembersErr != nil {
		return nil, s.listMembersErr
	}
	return s.membersList, nil
}

func (s *stubRepo) CreateInvitation(_ context.Context, inv account.Invitation, tokenHash string) (account.Invitation, error) {
	s.createInvitationCalls = append(s.createInvitationCalls, createInvitationCall{inv: inv, hash: tokenHash})
	if s.createInvitationErr != nil {
		return account.Invitation{}, s.createInvitationErr
	}
	inv.UUID = uuid.New()
	return inv, nil
}

func (s *stubRepo) RedeemInvitation(_ context.Context, tokenHash string, userID uuid.UUID) (account.Home, account.Role, error) {
	s.redeemInvitationCalls = append(s.redeemInvitationCalls, redeemInvitationCall{hash: tokenHash, userID: userID})
	if s.redeemErr != nil {
		return account.Home{}, "", s.redeemErr
	}
	return s.redeemHome, s.redeemRole, nil
}

func (s *stubRepo) RemoveMember(_ context.Context, homeID, userID uuid.UUID) error {
	s.removeMemberCalls = append(s.removeMemberCalls, removeMemberCall{homeID: homeID, userID: userID})
	return s.removeMemberErr
}

func TestProvisionFromSubjectCreatesUserAndHomeOnFirstSight(t *testing.T) {
	repo := &stubRepo{userErr: account.ErrUserNotFound}
	svc := NewAccountService(repo, "", metrics.NoopAccountProbe{})

	user, err := svc.ProvisionFromSubject(context.Background(), account.Identity{
		Subject: "subject-a",
		Email:   "ada@example.com",
	})
	if err != nil {
		t.Fatalf("ProvisionFromSubject: %v", err)
	}
	if user.UUID == uuid.Nil {
		t.Error("provisioned user has no id")
	}
	if len(repo.lookedUp) != 1 || repo.lookedUp[0] != "subject-a" {
		t.Errorf("looked up %v, want one lookup of subject-a", repo.lookedUp)
	}
	if len(repo.provisioned) != 1 {
		t.Fatalf("provisioned %d times, want 1", len(repo.provisioned))
	}
	want := account.Identity{Subject: "subject-a", Email: "ada@example.com"}
	if repo.provisioned[0] != want {
		t.Errorf("provisioned %+v, want %+v", repo.provisioned[0], want)
	}
	if got := repo.provisionedAt[0]; got.ID != uuid.Nil {
		t.Errorf("provisioned into home %s, want a newly created one", got.ID)
	}
}

func TestProvisionFromSubjectNeedsASubject(t *testing.T) {
	repo := &stubRepo{userErr: account.ErrUserNotFound}
	svc := NewAccountService(repo, "", metrics.NoopAccountProbe{})

	if _, err := svc.ProvisionFromSubject(context.Background(), account.Identity{Email: "ada@example.com"}); err == nil {
		t.Error("an empty subject was accepted")
	}
	if len(repo.provisioned) != 0 {
		t.Error("provisioned a user with no subject")
	}
}

func TestProvisionFromSubjectSurfacesLookupFailures(t *testing.T) {
	boom := errors.New("connection refused")
	repo := &stubRepo{userErr: boom}
	svc := NewAccountService(repo, "", metrics.NoopAccountProbe{})

	if _, err := svc.ProvisionFromSubject(context.Background(), account.Identity{Subject: "subject-a"}); !errors.Is(err, boom) {
		t.Errorf("got error %v, want %v", err, boom)
	}
	if len(repo.provisioned) != 0 {
		t.Error("provisioned a user after a failed lookup")
	}
}

func TestProvisionFromSubjectLeavesAKnownUserAlone(t *testing.T) {
	known := account.User{UUID: uuid.New(), Subject: "subject-a"}
	repo := &stubRepo{user: known}
	svc := NewAccountService(repo, "", metrics.NoopAccountProbe{})

	user, err := svc.ProvisionFromSubject(context.Background(), account.Identity{Subject: "subject-a"})
	if err != nil {
		t.Fatalf("ProvisionFromSubject: %v", err)
	}
	if user.UUID != known.UUID {
		t.Errorf("returned user %s, want the known %s", user.UUID, known.UUID)
	}
	if len(repo.lookedUp) != 1 || repo.lookedUp[0] != "subject-a" {
		t.Errorf("looked up %v, want one lookup of subject-a", repo.lookedUp)
	}
	if len(repo.provisioned) != 0 {
		t.Errorf("provisioned a user that already existed")
	}
}

func TestProvisionFromSubjectRefreshesAChangedProfile(t *testing.T) {
	known := account.User{UUID: uuid.New(), Subject: "subject-a", Email: "old@example.com", DisplayName: "Old Name"}
	moved := account.User{UUID: known.UUID, Subject: known.Subject, Email: "new@example.com", DisplayName: "New Name"}
	repo := &stubRepo{user: known, refreshedUser: moved}
	svc := NewAccountService(repo, "", metrics.NoopAccountProbe{})

	user, err := svc.ProvisionFromSubject(context.Background(), account.Identity{
		Subject:     "subject-a",
		Email:       "new@example.com",
		DisplayName: "New Name",
	})
	if err != nil {
		t.Fatalf("ProvisionFromSubject: %v", err)
	}
	if len(repo.refreshed) != 1 {
		t.Fatalf("%d refreshes, want 1", len(repo.refreshed))
	}
	if user.Email != moved.Email || user.DisplayName != moved.DisplayName {
		t.Errorf("returned %q / %q, want the refreshed %q / %q", user.Email, user.DisplayName, moved.Email, moved.DisplayName)
	}
}

// Every request carries the profile, so a refresh on each one would be a write
// per read. Only a difference is worth the round trip.
func TestProvisionFromSubjectLeavesAnUnchangedProfileAlone(t *testing.T) {
	known := account.User{UUID: uuid.New(), Subject: "subject-a", Email: "a@example.com", DisplayName: "A"}
	repo := &stubRepo{user: known}
	svc := NewAccountService(repo, "", metrics.NoopAccountProbe{})

	if _, err := svc.ProvisionFromSubject(context.Background(), account.Identity{
		Subject:     "subject-a",
		Email:       "a@example.com",
		DisplayName: "A",
	}); err != nil {
		t.Fatalf("ProvisionFromSubject: %v", err)
	}
	if len(repo.refreshed) != 0 {
		t.Errorf("refreshed a profile nothing had changed")
	}
}

// The edge forwards email and name only while it is configured to, so an
// absent one must not overwrite a good stored value with nothing.
func TestProvisionFromSubjectIgnoresAClaimThatDidNotArrive(t *testing.T) {
	known := account.User{UUID: uuid.New(), Subject: "subject-a", Email: "a@example.com", DisplayName: "A"}
	repo := &stubRepo{user: known}
	svc := NewAccountService(repo, "", metrics.NoopAccountProbe{})

	user, err := svc.ProvisionFromSubject(context.Background(), account.Identity{Subject: "subject-a"})
	if err != nil {
		t.Fatalf("ProvisionFromSubject: %v", err)
	}
	if len(repo.refreshed) != 0 {
		t.Errorf("an identity carrying no claims triggered a refresh")
	}
	if user.Email != known.Email || user.DisplayName != known.DisplayName {
		t.Errorf("returned %q / %q, want the stored %q / %q", user.Email, user.DisplayName, known.Email, known.DisplayName)
	}
}

// A profile one request out of date is not a reason to refuse the request.
func TestProvisionFromSubjectSurvivesAFailedRefresh(t *testing.T) {
	known := account.User{UUID: uuid.New(), Subject: "subject-a", Email: "old@example.com"}
	repo := &stubRepo{user: known, refreshProfErr: errors.New("boom")}
	svc := NewAccountService(repo, "", metrics.NoopAccountProbe{})

	user, err := svc.ProvisionFromSubject(context.Background(), account.Identity{
		Subject: "subject-a",
		Email:   "new@example.com",
	})
	if err != nil {
		t.Fatalf("ProvisionFromSubject: %v", err)
	}
	if user.UUID != known.UUID || user.Email != known.Email {
		t.Errorf("returned %s / %q, want the stored %s / %q", user.UUID, user.Email, known.UUID, known.Email)
	}
}

func TestFounderSubjectAttachesToTheFounderHome(t *testing.T) {
	repo := &stubRepo{userErr: account.ErrUserNotFound}
	svc := NewAccountService(repo, "founder-subject", metrics.NoopAccountProbe{})

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
	svc := NewAccountService(repo, "founder-subject", metrics.NoopAccountProbe{})

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
			svc := NewAccountService(repo, "", metrics.NoopAccountProbe{})

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
	svc := NewAccountService(repo, "", metrics.NoopAccountProbe{})

	got, err := svc.ResolveActiveHome(context.Background(), account.User{UUID: uuid.New()}, uuid.Nil)
	if err != nil {
		t.Fatalf("ResolveActiveHome: %v", err)
	}
	if got.UUID != home.UUID {
		t.Errorf("resolved home %s, want %s", got.UUID, home.UUID)
	}
}

func TestResolveActiveHomeGivesAHomelessUserOneBack(t *testing.T) {
	repo := &stubRepo{homeErr: account.ErrHomeNotFound}
	svc := NewAccountService(repo, "", metrics.NoopAccountProbe{})

	got, err := svc.ResolveActiveHome(context.Background(), account.User{
		UUID:    uuid.New(),
		Subject: "subject-a",
		Email:   "ada@example.com",
	}, uuid.Nil)
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
	svc := NewAccountService(repo, "", metrics.NoopAccountProbe{})

	if _, err := svc.ResolveActiveHome(context.Background(), account.User{UUID: uuid.New()}, uuid.Nil); !errors.Is(err, boom) {
		t.Errorf("got error %v, want %v", err, boom)
	}
	if len(repo.provisioned) != 0 {
		t.Errorf("provisioned a home after a failed lookup")
	}
}

// This suite pins that a requested home is settled by FindHomeForUser alone,
// never by falling through to most-recent or provisioning a fresh one.
func TestResolveActiveHomeWithARequestedHomeNeverFallsBack(t *testing.T) {
	requested := uuid.New()
	home := account.Home{UUID: requested, Name: "Someone Else's Book"}
	repo := &stubRepo{findHomeForUserHome: home}
	svc := NewAccountService(repo, "", metrics.NoopAccountProbe{})

	got, err := svc.ResolveActiveHome(context.Background(), account.User{UUID: uuid.New()}, requested)
	if err != nil {
		t.Fatalf("ResolveActiveHome: %v", err)
	}
	if got.UUID != requested {
		t.Errorf("resolved home %s, want %s", got.UUID, requested)
	}
	if len(repo.findHomeForUserCalls) != 1 || repo.findHomeForUserCalls[0].homeID != requested {
		t.Errorf("FindHomeForUser calls %+v, want one call naming %s", repo.findHomeForUserCalls, requested)
	}
	if repo.findMostRecentHomeCalls != 0 {
		t.Error("fell back to the most recently joined home despite a request naming one")
	}
	if len(repo.provisioned) != 0 {
		t.Error("provisioned a home despite a request naming one")
	}
}

// This is the guard that stops an X-Home header naming somebody else's home
// from quietly minting a fresh one: a requested home the caller cannot prove
// membership of must come back as ErrHomeNotFound, not a brand new book.
func TestResolveActiveHomeRefusesARequestedHomeTheUserIsNotIn(t *testing.T) {
	repo := &stubRepo{findHomeForUserErr: account.ErrHomeNotFound}
	svc := NewAccountService(repo, "", metrics.NoopAccountProbe{})

	_, err := svc.ResolveActiveHome(context.Background(), account.User{UUID: uuid.New()}, uuid.New())
	if !errors.Is(err, account.ErrHomeNotFound) {
		t.Errorf("got error %v, want %v", err, account.ErrHomeNotFound)
	}
	if repo.findMostRecentHomeCalls != 0 {
		t.Error("fell back to the most recently joined home for a home the caller cannot prove membership of")
	}
	if len(repo.provisioned) != 0 {
		t.Error("minted a fresh home for a caller naming somebody else's")
	}
}

func TestInviteRefusesANonOwner(t *testing.T) {
	repo := &stubRepo{role: account.RoleMember}
	svc := NewAccountService(repo, "", metrics.NoopAccountProbe{})

	if _, _, err := svc.Invite(context.Background(), uuid.New(), uuid.New(), "person@example.com", account.RoleMember); !errors.Is(err, account.ErrForbidden) {
		t.Errorf("got error %v, want %v", err, account.ErrForbidden)
	}
	if len(repo.createInvitationCalls) != 0 {
		t.Error("created an invitation for a caller who is only a member")
	}
}

func TestInviteRefusesANonMember(t *testing.T) {
	repo := &stubRepo{roleErr: account.ErrForbidden}
	svc := NewAccountService(repo, "", metrics.NoopAccountProbe{})

	if _, _, err := svc.Invite(context.Background(), uuid.New(), uuid.New(), "person@example.com", account.RoleMember); !errors.Is(err, account.ErrForbidden) {
		t.Errorf("got error %v, want %v", err, account.ErrForbidden)
	}
	if len(repo.createInvitationCalls) != 0 {
		t.Error("created an invitation for a caller with no standing in the home at all")
	}
}

func TestInviteByAnOwnerCreatesOneInvitation(t *testing.T) {
	repo := &stubRepo{role: account.RoleOwner}
	svc := NewAccountService(repo, "", metrics.NoopAccountProbe{}).(*accountService)
	fixedNow := time.Date(2030, 1, 1, 12, 0, 0, 0, time.UTC)
	svc.now = func() time.Time { return fixedNow }

	actorID, homeID := uuid.New(), uuid.New()
	inv, token, err := svc.Invite(context.Background(), actorID, homeID, "person@example.com", account.RoleMember)
	if err != nil {
		t.Fatalf("Invite: %v", err)
	}
	if inv.HomeID != homeID {
		t.Errorf("invitation home %s, want %s", inv.HomeID, homeID)
	}
	if len(repo.createInvitationCalls) != 1 {
		t.Fatalf("created %d invitations, want 1", len(repo.createInvitationCalls))
	}
	call := repo.createInvitationCalls[0]
	if !call.inv.ExpiresAt.Equal(fixedNow.Add(InvitationTTL)) {
		t.Errorf("expires at %v, want %v", call.inv.ExpiresAt, fixedNow.Add(InvitationTTL))
	}
	if call.inv.InvitedBy != actorID {
		t.Errorf("invited by %s, want %s", call.inv.InvitedBy, actorID)
	}
	// The repository is only ever handed the hash: a copy of that row joins
	// nobody to anything, which only holds if the plaintext never reaches it.
	if call.hash != account.HashInvitationToken(token) {
		t.Error("repository was not given the hash of the returned token")
	}
	if call.hash == token {
		t.Error("repository was handed the plaintext token")
	}
}

func TestInviteReturnsADifferentHighEntropyTokenEachCall(t *testing.T) {
	repo := &stubRepo{role: account.RoleOwner}
	svc := NewAccountService(repo, "", metrics.NoopAccountProbe{})

	_, tokenA, err := svc.Invite(context.Background(), uuid.New(), uuid.New(), "a@example.com", account.RoleMember)
	if err != nil {
		t.Fatalf("Invite: %v", err)
	}
	_, tokenB, err := svc.Invite(context.Background(), uuid.New(), uuid.New(), "b@example.com", account.RoleMember)
	if err != nil {
		t.Fatalf("Invite: %v", err)
	}
	if tokenA == tokenB {
		t.Error("two invitations shared one token")
	}
	for _, token := range []string{tokenA, tokenB} {
		decoded, err := base64.RawURLEncoding.DecodeString(token)
		if err != nil {
			t.Fatalf("token %q is not base64url: %v", token, err)
		}
		if len(decoded) < 32 {
			t.Errorf("token %q decodes to %d bytes, want at least 32", token, len(decoded))
		}
	}
}

func TestInviteDefaultsAnEmptyRoleToMember(t *testing.T) {
	repo := &stubRepo{role: account.RoleOwner}
	svc := NewAccountService(repo, "", metrics.NoopAccountProbe{})

	if _, _, err := svc.Invite(context.Background(), uuid.New(), uuid.New(), "person@example.com", ""); err != nil {
		t.Fatalf("Invite: %v", err)
	}
	if got := repo.createInvitationCalls[0].inv.Role; got != account.RoleMember {
		t.Errorf("defaulted role %q, want %q", got, account.RoleMember)
	}
}

func TestInviteRejectsAJunkRole(t *testing.T) {
	repo := &stubRepo{role: account.RoleOwner}
	svc := NewAccountService(repo, "", metrics.NoopAccountProbe{})

	if _, _, err := svc.Invite(context.Background(), uuid.New(), uuid.New(), "person@example.com", account.Role("wizard")); !errors.Is(err, account.ErrInvalidRole) {
		t.Errorf("got error %v, want %v", err, account.ErrInvalidRole)
	}
	if len(repo.createInvitationCalls) != 0 {
		t.Error("created an invitation with an invalid role")
	}
}

func TestInviteRequiresANonBlankEmail(t *testing.T) {
	repo := &stubRepo{role: account.RoleOwner}
	svc := NewAccountService(repo, "", metrics.NoopAccountProbe{})

	if _, _, err := svc.Invite(context.Background(), uuid.New(), uuid.New(), "   ", account.RoleMember); !errors.Is(err, account.ErrEmailRequired) {
		t.Errorf("got error %v, want %v", err, account.ErrEmailRequired)
	}
	if len(repo.createInvitationCalls) != 0 {
		t.Error("created an invitation with no email")
	}
}

// Standing is decided before the body is read, so a non-owner learns only
// that they may not invite, never whether their request was otherwise good.
func TestInviteDecidesStandingBeforeValidatingTheRole(t *testing.T) {
	repo := &stubRepo{role: account.RoleMember}
	svc := NewAccountService(repo, "", metrics.NoopAccountProbe{})

	if _, _, err := svc.Invite(context.Background(), uuid.New(), uuid.New(), "person@example.com", account.Role("wizard")); !errors.Is(err, account.ErrForbidden) {
		t.Errorf("got error %v, want %v", err, account.ErrForbidden)
	}
}

func TestAcceptInvitationHashesTheTokenBeforeItReachesTheRepository(t *testing.T) {
	repo := &stubRepo{redeemHome: account.Home{UUID: uuid.New()}, redeemRole: account.RoleMember}
	svc := NewAccountService(repo, "", metrics.NoopAccountProbe{})

	const token = "raw-token-value"
	if _, _, err := svc.AcceptInvitation(context.Background(), uuid.New(), token); err != nil {
		t.Fatalf("AcceptInvitation: %v", err)
	}
	if len(repo.redeemInvitationCalls) != 1 {
		t.Fatalf("redeemed %d times, want 1", len(repo.redeemInvitationCalls))
	}
	if got := repo.redeemInvitationCalls[0].hash; got != account.HashInvitationToken(token) {
		t.Errorf("repository saw %q, want the hash %q", got, account.HashInvitationToken(token))
	}
}

func TestAcceptInvitationRefusesABlankTokenWithoutReachingTheRepository(t *testing.T) {
	repo := &stubRepo{}
	svc := NewAccountService(repo, "", metrics.NoopAccountProbe{})

	if _, _, err := svc.AcceptInvitation(context.Background(), uuid.New(), "   "); !errors.Is(err, account.ErrInvitationNotFound) {
		t.Errorf("got error %v, want %v", err, account.ErrInvitationNotFound)
	}
	if len(repo.redeemInvitationCalls) != 0 {
		t.Error("reached the repository with a blank token")
	}
}

// Expiry and single use are enforced in SQL and covered by a separate
// integration suite; this only pins that the service does not swallow or
// remap what the repository decided.
func TestAcceptInvitationSurfacesRepositoryErrorsUnchanged(t *testing.T) {
	cases := map[string]error{
		"expired": account.ErrInvitationExpired,
		"used":    account.ErrInvitationUsed,
		"unknown": account.ErrInvitationNotFound,
	}
	for name, want := range cases {
		t.Run(name, func(t *testing.T) {
			repo := &stubRepo{redeemErr: want}
			svc := NewAccountService(repo, "", metrics.NoopAccountProbe{})

			if _, _, err := svc.AcceptInvitation(context.Background(), uuid.New(), "some-token"); !errors.Is(err, want) {
				t.Errorf("got error %v, want %v", err, want)
			}
		})
	}
}

func TestListMembersRefusesANonMember(t *testing.T) {
	repo := &stubRepo{roleErr: account.ErrForbidden}
	svc := NewAccountService(repo, "", metrics.NoopAccountProbe{})

	if _, err := svc.ListMembers(context.Background(), uuid.New(), uuid.New()); !errors.Is(err, account.ErrForbidden) {
		t.Errorf("got error %v, want %v", err, account.ErrForbidden)
	}
	if len(repo.listMembersCalls) != 0 {
		t.Error("fetched the member list for a caller with no standing in the home")
	}
}

func TestListMembersAllowsAPlainMember(t *testing.T) {
	want := []account.Member{{User: account.User{UUID: uuid.New()}, Role: account.RoleMember}}
	repo := &stubRepo{role: account.RoleMember, membersList: want}
	svc := NewAccountService(repo, "", metrics.NoopAccountProbe{})

	got, err := svc.ListMembers(context.Background(), uuid.New(), uuid.New())
	if err != nil {
		t.Fatalf("ListMembers: %v", err)
	}
	if len(got) != len(want) {
		t.Errorf("got %d members, want %d", len(got), len(want))
	}
	if len(repo.listMembersCalls) != 1 {
		t.Errorf("fetched the member list %d times, want 1", len(repo.listMembersCalls))
	}
}

func TestRemoveMemberRefusesANonOwner(t *testing.T) {
	repo := &stubRepo{role: account.RoleMember}
	svc := NewAccountService(repo, "", metrics.NoopAccountProbe{})

	if err := svc.RemoveMember(context.Background(), uuid.New(), uuid.New(), uuid.New()); !errors.Is(err, account.ErrForbidden) {
		t.Errorf("got error %v, want %v", err, account.ErrForbidden)
	}
	if len(repo.removeMemberCalls) != 0 {
		t.Error("removed a member on a non-owner's say")
	}
}

func TestRemoveMemberSurfacesLastOwnerUnchanged(t *testing.T) {
	repo := &stubRepo{role: account.RoleOwner, removeMemberErr: account.ErrLastOwner}
	svc := NewAccountService(repo, "", metrics.NoopAccountProbe{})

	if err := svc.RemoveMember(context.Background(), uuid.New(), uuid.New(), uuid.New()); !errors.Is(err, account.ErrLastOwner) {
		t.Errorf("got error %v, want %v", err, account.ErrLastOwner)
	}
}
