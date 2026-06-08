package service

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/kieranajp/the-bluer-book/internal/domain/account"
)

// memRepo is a minimal in-memory account.Repository for unit testing the
// service. Tests check the surface contracts (provision-on-miss, founder
// linkage, invite/accept lifecycle, owner-only authorisation, sole-owner
// guard) — the DB-backed adapter is exercised by the integration test in
// internal/infrastructure/storage/repository.
type memRepo struct {
	mu          sync.Mutex
	users       map[uuid.UUID]account.User
	homes       map[uuid.UUID]account.Home
	memberships map[uuid.UUID]map[uuid.UUID]account.Role // homeID -> userID -> role
	invitations map[string]account.Invitation            // token -> invitation
}

func newMemRepo() *memRepo {
	return &memRepo{
		users:       map[uuid.UUID]account.User{},
		homes:       map[uuid.UUID]account.Home{},
		memberships: map[uuid.UUID]map[uuid.UUID]account.Role{},
		invitations: map[string]account.Invitation{},
	}
}

// seedFounderHome is what migration 00010 does in real life: pre-create
// the founder home so first-login linkage has a target.
func (r *memRepo) seedFounderHome() {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.homes[FounderHomeID] = account.Home{
		UUID:      FounderHomeID,
		Name:      "Founder",
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}
}

func (r *memRepo) GetUserBySubject(_ context.Context, subject string) (*account.User, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	for _, u := range r.users {
		if u.Subject == subject {
			out := u
			return &out, nil
		}
	}
	return nil, account.ErrUserNotFound
}

func (r *memRepo) GetUserByUUID(_ context.Context, id uuid.UUID) (*account.User, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	u, ok := r.users[id]
	if !ok {
		return nil, account.ErrUserNotFound
	}
	return &u, nil
}

func (r *memRepo) CreateUser(_ context.Context, subject, email, displayName string) (*account.User, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	u := account.User{
		UUID:        uuid.New(),
		Subject:     subject,
		Email:       email,
		DisplayName: displayName,
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}
	r.users[u.UUID] = u
	return &u, nil
}

func (r *memRepo) CreateHome(_ context.Context, name string) (*account.Home, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	h := account.Home{
		UUID:      uuid.New(),
		Name:      name,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}
	r.homes[h.UUID] = h
	return &h, nil
}

func (r *memRepo) GetHomeByID(_ context.Context, id uuid.UUID) (*account.Home, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	h, ok := r.homes[id]
	if !ok {
		return nil, account.ErrHomeNotFound
	}
	return &h, nil
}

func (r *memRepo) GetHomeForUserByID(_ context.Context, userID, homeID uuid.UUID) (*account.Home, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if _, ok := r.memberships[homeID][userID]; !ok {
		return nil, account.ErrHomeNotFound
	}
	h, ok := r.homes[homeID]
	if !ok {
		return nil, account.ErrHomeNotFound
	}
	return &h, nil
}

func (r *memRepo) GetMostRecentHomeForUser(_ context.Context, userID uuid.UUID) (*account.Home, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	for homeID, members := range r.memberships {
		if _, ok := members[userID]; ok {
			h := r.homes[homeID]
			return &h, nil
		}
	}
	return nil, account.ErrHomeNotFound
}

func (r *memRepo) ListHomesForUser(_ context.Context, userID uuid.UUID) ([]account.Membership, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	var out []account.Membership
	for homeID, members := range r.memberships {
		if role, ok := members[userID]; ok {
			out = append(out, account.Membership{Home: r.homes[homeID], Role: role})
		}
	}
	return out, nil
}

func (r *memRepo) AddMember(_ context.Context, homeID, userID uuid.UUID, role account.Role) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.memberships[homeID] == nil {
		r.memberships[homeID] = map[uuid.UUID]account.Role{}
	}
	r.memberships[homeID][userID] = role
	return nil
}

func (r *memRepo) RemoveMember(_ context.Context, homeID, userID uuid.UUID) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	delete(r.memberships[homeID], userID)
	return nil
}

func (r *memRepo) GetMembership(_ context.Context, homeID, userID uuid.UUID) (account.Role, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	role, ok := r.memberships[homeID][userID]
	if !ok {
		return "", account.ErrForbidden
	}
	return role, nil
}

func (r *memRepo) ListMembers(_ context.Context, homeID uuid.UUID) ([]account.MemberWithUser, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	var out []account.MemberWithUser
	for userID, role := range r.memberships[homeID] {
		out = append(out, account.MemberWithUser{User: r.users[userID], Role: role})
	}
	return out, nil
}

func (r *memRepo) CountOwners(_ context.Context, homeID uuid.UUID) (int, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	count := 0
	for _, role := range r.memberships[homeID] {
		if role == account.RoleOwner {
			count++
		}
	}
	return count, nil
}

func (r *memRepo) CreateInvitation(_ context.Context, inv account.Invitation) (*account.Invitation, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	inv.UUID = uuid.New()
	inv.CreatedAt = time.Now()
	r.invitations[inv.Token] = inv
	return &inv, nil
}

func (r *memRepo) GetInvitationByToken(_ context.Context, token string) (*account.Invitation, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	inv, ok := r.invitations[token]
	if !ok {
		return nil, account.ErrInvitationNotFound
	}
	return &inv, nil
}

func (r *memRepo) MarkInvitationAccepted(_ context.Context, invitationID uuid.UUID) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	for token, inv := range r.invitations {
		if inv.UUID == invitationID {
			now := time.Now()
			inv.AcceptedAt = &now
			r.invitations[token] = inv
			return nil
		}
	}
	return account.ErrInvitationNotFound
}

func (r *memRepo) ListInvitations(_ context.Context, homeID uuid.UUID) ([]account.Invitation, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	var out []account.Invitation
	for _, inv := range r.invitations {
		if inv.HomeID == homeID && inv.AcceptedAt == nil {
			out = append(out, inv)
		}
	}
	return out, nil
}

// --- tests ---

func TestProvisionFromSubject_FirstLoginCreatesUserAndHome(t *testing.T) {
	repo := newMemRepo()
	svc := New(repo, Config{}, nil)

	user, home, err := svc.ProvisionFromSubject(context.Background(), "kratos-id-new")
	if err != nil {
		t.Fatalf("ProvisionFromSubject: %v", err)
	}
	if user.Subject != "kratos-id-new" {
		t.Errorf("user subject = %q, want kratos-id-new", user.Subject)
	}
	if home.UUID == FounderHomeID {
		t.Errorf("new user should not be linked to founder home without FOUNDER_SUBJECT")
	}
	if home.Name != "My Book" {
		t.Errorf("home name = %q, want \"My Book\"", home.Name)
	}

	// Owner membership must exist.
	role, err := repo.GetMembership(context.Background(), home.UUID, user.UUID)
	if err != nil {
		t.Fatalf("expected owner membership, got err: %v", err)
	}
	if role != account.RoleOwner {
		t.Errorf("first-login role = %q, want owner", role)
	}
}

func TestProvisionFromSubject_SecondLoginReusesUserAndHome(t *testing.T) {
	repo := newMemRepo()
	svc := New(repo, Config{}, nil)

	first, firstHome, err := svc.ProvisionFromSubject(context.Background(), "kratos-id-stable")
	if err != nil {
		t.Fatalf("first ProvisionFromSubject: %v", err)
	}
	second, secondHome, err := svc.ProvisionFromSubject(context.Background(), "kratos-id-stable")
	if err != nil {
		t.Fatalf("second ProvisionFromSubject: %v", err)
	}
	if first.UUID != second.UUID {
		t.Errorf("user uuid changed across logins: %s vs %s", first.UUID, second.UUID)
	}
	if firstHome.UUID != secondHome.UUID {
		t.Errorf("home uuid changed across logins: %s vs %s", firstHome.UUID, secondHome.UUID)
	}
}

func TestProvisionFromSubject_FounderSubjectLinksToFounderHome(t *testing.T) {
	repo := newMemRepo()
	repo.seedFounderHome()
	svc := New(repo, Config{FounderSubject: "kratos-id-kieran"}, nil)

	user, home, err := svc.ProvisionFromSubject(context.Background(), "kratos-id-kieran")
	if err != nil {
		t.Fatalf("ProvisionFromSubject: %v", err)
	}
	if home.UUID != FounderHomeID {
		t.Fatalf("founder login should land in founder home, got %s", home.UUID)
	}

	// Founder is an owner of the founder home.
	role, err := repo.GetMembership(context.Background(), FounderHomeID, user.UUID)
	if err != nil {
		t.Fatalf("founder membership missing: %v", err)
	}
	if role != account.RoleOwner {
		t.Errorf("founder role = %q, want owner", role)
	}
}

func TestProvisionFromSubject_NonFounderIgnoresFounderHome(t *testing.T) {
	repo := newMemRepo()
	repo.seedFounderHome()
	svc := New(repo, Config{FounderSubject: "kratos-id-kieran"}, nil)

	_, home, err := svc.ProvisionFromSubject(context.Background(), "kratos-id-stranger")
	if err != nil {
		t.Fatalf("ProvisionFromSubject: %v", err)
	}
	if home.UUID == FounderHomeID {
		t.Fatalf("stranger should not land in founder home")
	}
}

func TestInviteToHome_RequiresOwner(t *testing.T) {
	repo := newMemRepo()
	svc := New(repo, Config{}, nil)

	owner, ownerHome, _ := svc.ProvisionFromSubject(context.Background(), "owner")
	_, _ = owner, ownerHome
	stranger, _, _ := svc.ProvisionFromSubject(context.Background(), "stranger")

	// Owner can invite.
	inv, err := svc.InviteToHome(context.Background(), owner.UUID, ownerHome.UUID, "friend@example.com", account.RoleMember)
	if err != nil {
		t.Fatalf("owner invite failed: %v", err)
	}
	if inv.Token == "" {
		t.Errorf("invite missing token")
	}

	// Stranger cannot invite to a home they don't belong to.
	if _, err := svc.InviteToHome(context.Background(), stranger.UUID, ownerHome.UUID, "x@example.com", account.RoleMember); !errors.Is(err, account.ErrForbidden) {
		t.Fatalf("stranger invite got %v, want ErrForbidden", err)
	}
}

func TestAcceptInvitation_AddsMembership(t *testing.T) {
	repo := newMemRepo()
	svc := New(repo, Config{}, nil)

	owner, ownerHome, _ := svc.ProvisionFromSubject(context.Background(), "owner")
	invitee, _, _ := svc.ProvisionFromSubject(context.Background(), "invitee")

	inv, err := svc.InviteToHome(context.Background(), owner.UUID, ownerHome.UUID, "invitee@example.com", account.RoleMember)
	if err != nil {
		t.Fatalf("invite: %v", err)
	}

	home, err := svc.AcceptInvitation(context.Background(), invitee.UUID, inv.Token)
	if err != nil {
		t.Fatalf("accept: %v", err)
	}
	if home.UUID != ownerHome.UUID {
		t.Errorf("accepted home uuid = %s, want %s", home.UUID, ownerHome.UUID)
	}

	role, err := repo.GetMembership(context.Background(), ownerHome.UUID, invitee.UUID)
	if err != nil {
		t.Fatalf("invitee membership missing: %v", err)
	}
	if role != account.RoleMember {
		t.Errorf("invitee role = %q, want member", role)
	}
}

func TestAcceptInvitation_RejectsExpired(t *testing.T) {
	repo := newMemRepo()
	now := time.Now()
	svc := New(repo, Config{}, func() time.Time { return now })

	owner, ownerHome, _ := svc.ProvisionFromSubject(context.Background(), "owner")
	invitee, _, _ := svc.ProvisionFromSubject(context.Background(), "invitee")
	inv, _ := svc.InviteToHome(context.Background(), owner.UUID, ownerHome.UUID, "invitee@example.com", account.RoleMember)

	// Fast-forward past expiry.
	svc.(*service).now = func() time.Time { return now.Add(2 * DefaultInvitationTTL) }

	_, err := svc.AcceptInvitation(context.Background(), invitee.UUID, inv.Token)
	if !errors.Is(err, account.ErrInvitationExpired) {
		t.Fatalf("got %v, want ErrInvitationExpired", err)
	}
}

func TestAcceptInvitation_RejectsAlreadyAccepted(t *testing.T) {
	repo := newMemRepo()
	svc := New(repo, Config{}, nil)

	owner, ownerHome, _ := svc.ProvisionFromSubject(context.Background(), "owner")
	invitee, _, _ := svc.ProvisionFromSubject(context.Background(), "invitee")
	inv, _ := svc.InviteToHome(context.Background(), owner.UUID, ownerHome.UUID, "invitee@example.com", account.RoleMember)

	if _, err := svc.AcceptInvitation(context.Background(), invitee.UUID, inv.Token); err != nil {
		t.Fatalf("first accept: %v", err)
	}
	if _, err := svc.AcceptInvitation(context.Background(), invitee.UUID, inv.Token); !errors.Is(err, account.ErrInvitationAlreadyAccepted) {
		t.Fatalf("got %v, want ErrInvitationAlreadyAccepted", err)
	}
}

func TestRemoveMember_RefusesSoleOwner(t *testing.T) {
	repo := newMemRepo()
	svc := New(repo, Config{}, nil)

	owner, ownerHome, _ := svc.ProvisionFromSubject(context.Background(), "owner")

	if err := svc.RemoveMember(context.Background(), owner.UUID, ownerHome.UUID, owner.UUID); !errors.Is(err, account.ErrCannotRemoveSoleOwner) {
		t.Fatalf("got %v, want ErrCannotRemoveSoleOwner", err)
	}
}

func TestRemoveMember_OwnerCanRemoveOther(t *testing.T) {
	repo := newMemRepo()
	svc := New(repo, Config{}, nil)

	owner, ownerHome, _ := svc.ProvisionFromSubject(context.Background(), "owner")
	invitee, _, _ := svc.ProvisionFromSubject(context.Background(), "invitee")
	inv, _ := svc.InviteToHome(context.Background(), owner.UUID, ownerHome.UUID, "x@example.com", account.RoleMember)
	if _, err := svc.AcceptInvitation(context.Background(), invitee.UUID, inv.Token); err != nil {
		t.Fatalf("accept: %v", err)
	}

	if err := svc.RemoveMember(context.Background(), owner.UUID, ownerHome.UUID, invitee.UUID); err != nil {
		t.Fatalf("remove: %v", err)
	}

	if _, err := repo.GetMembership(context.Background(), ownerHome.UUID, invitee.UUID); !errors.Is(err, account.ErrForbidden) {
		t.Fatalf("expected invitee gone (ErrForbidden), got %v", err)
	}
}
