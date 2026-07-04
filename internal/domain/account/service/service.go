// Package service implements the account domain operations the
// resolution layer (auth middleware) and account API handlers depend on:
// provision-on-first-login, listing a user's homes, invite issue/accept,
// and member management.
package service

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"

	"github.com/kieranajp/the-bluer-book/internal/domain/account"
)

// FounderHomeID is the UUID stamped onto every backfilled tenant row by
// migration 00010. The home itself exists from then; the first user
// whose subject matches FounderSubject (see Config) is attached to it as
// the owner on their first login. Any other first-login provisions a
// fresh home for that user.
var FounderHomeID = uuid.MustParse("00000000-0000-0000-0000-000000000001")

// DefaultInvitationTTL is how long an outstanding invite remains
// redeemable. Seven days matches the usual "team invite" convention and
// keeps the migrations / Phase 6 deletion contracts simple.
const DefaultInvitationTTL = 7 * 24 * time.Hour

// Config wires runtime values into the service.
type Config struct {
	// FounderSubject is the Kratos identity id (X-User value) that should
	// be linked to the pre-existing founder home on first login. If
	// empty, no founder linkage happens and every first-login provisions
	// a fresh home; in that scenario the founder home stays orphaned
	// until an operator manually attaches a membership.
	FounderSubject string
}

// Service is the door into the account domain. Handlers and the auth
// resolver call it; nothing reaches the AccountRepository directly.
type Service interface {
	// ProvisionFromSubject finds a user by subject or creates one. The
	// returned User always has at least one membership: either the
	// founder home (if FounderSubject matches) or a freshly-created home
	// owned by them.
	ProvisionFromSubject(ctx context.Context, subject string) (*account.User, *account.Home, error)

	// ResolveActiveHome picks the home for a request. If requestedHomeID
	// is non-nil it must be a home the user belongs to; otherwise the
	// user's most-recent membership is used. Errors with
	// account.ErrHomeNotFound when the user has no homes at all (which
	// should never happen after ProvisionFromSubject).
	ResolveActiveHome(ctx context.Context, userID uuid.UUID, requestedHomeID *uuid.UUID) (*account.Home, error)

	ListHomesForUser(ctx context.Context, userID uuid.UUID) ([]account.Membership, error)

	// InviteToHome creates an invitation token. The caller must be an
	// owner of homeID; otherwise account.ErrForbidden.
	InviteToHome(ctx context.Context, callerID, homeID uuid.UUID, email string, role account.Role) (*account.Invitation, error)

	// AcceptInvitation redeems a token: marks the invitation accepted
	// and adds the user as a member of the named home. Errors with
	// ErrInvitationExpired or ErrInvitationAlreadyAccepted as relevant.
	AcceptInvitation(ctx context.Context, userID uuid.UUID, token string) (*account.Home, error)

	ListMembers(ctx context.Context, callerID, homeID uuid.UUID) ([]account.MemberWithUser, error)

	// RemoveMember removes a member from a home. Caller must be an owner
	// of homeID; removing the sole owner is refused with
	// ErrCannotRemoveSoleOwner.
	RemoveMember(ctx context.Context, callerID, homeID, targetID uuid.UUID) error
}

type service struct {
	repo account.Repository
	cfg  Config
	now  func() time.Time
}

// New builds an account service. Pass time.Now (or a fake in tests) as
// nowFn; nil falls back to time.Now.
func New(repo account.Repository, cfg Config, nowFn func() time.Time) Service {
	if nowFn == nil {
		nowFn = time.Now
	}
	return &service{repo: repo, cfg: cfg, now: nowFn}
}

func (s *service) ProvisionFromSubject(ctx context.Context, subject string) (*account.User, *account.Home, error) {
	if subject == "" {
		return nil, nil, errors.New("subject is required")
	}

	// Happy path: user already exists.
	user, err := s.repo.GetUserBySubject(ctx, subject)
	if err == nil {
		home, err := s.repo.GetMostRecentHomeForUser(ctx, user.UUID)
		if err == nil {
			return user, home, nil
		}
		if !errors.Is(err, account.ErrHomeNotFound) {
			return nil, nil, err
		}
		// User exists but lost their last membership (an edge case Phase 6
		// can produce). Treat as a fresh provision: attach to founder if
		// they're the founder, else give them a new home.
		home, err = s.attachToFounderOrNew(ctx, user)
		if err != nil {
			return nil, nil, err
		}
		return user, home, nil
	}
	if !errors.Is(err, account.ErrUserNotFound) {
		return nil, nil, err
	}

	// First login for this subject — create the user, then attach.
	user, err = s.repo.CreateUser(ctx, subject, "", "")
	if err != nil {
		return nil, nil, err
	}
	home, err := s.attachToFounderOrNew(ctx, user)
	if err != nil {
		return nil, nil, err
	}
	return user, home, nil
}

// attachToFounderOrNew adds the user to the founder home (if their
// subject matches FounderSubject) or creates a fresh home for them. In
// both cases the user ends up with an owner membership.
func (s *service) attachToFounderOrNew(ctx context.Context, user *account.User) (*account.Home, error) {
	if s.cfg.FounderSubject != "" && user.Subject == s.cfg.FounderSubject {
		// Sanity check that the founder home actually exists — it should,
		// because migration 00010 inserted it. If it doesn't, fall through
		// to creating a fresh home so the user isn't stranded.
		founder, err := s.repo.GetHomeByID(ctx, FounderHomeID)
		if err == nil {
			if err := s.repo.AddMember(ctx, FounderHomeID, user.UUID, account.RoleOwner); err != nil {
				return nil, err
			}
			return founder, nil
		}
		if !errors.Is(err, account.ErrHomeNotFound) {
			return nil, err
		}
	}

	name := defaultHomeName(user)
	home, err := s.repo.CreateHome(ctx, name)
	if err != nil {
		return nil, err
	}
	if err := s.repo.AddMember(ctx, home.UUID, user.UUID, account.RoleOwner); err != nil {
		return nil, err
	}
	return home, nil
}

func defaultHomeName(u *account.User) string {
	if u.DisplayName != "" {
		return u.DisplayName + "'s Book"
	}
	return "My Book"
}

func (s *service) ResolveActiveHome(ctx context.Context, userID uuid.UUID, requestedHomeID *uuid.UUID) (*account.Home, error) {
	if requestedHomeID != nil {
		return s.repo.GetHomeForUserByID(ctx, userID, *requestedHomeID)
	}
	return s.repo.GetMostRecentHomeForUser(ctx, userID)
}

func (s *service) ListHomesForUser(ctx context.Context, userID uuid.UUID) ([]account.Membership, error) {
	return s.repo.ListHomesForUser(ctx, userID)
}

func (s *service) InviteToHome(ctx context.Context, callerID, homeID uuid.UUID, email string, role account.Role) (*account.Invitation, error) {
	if err := s.requireOwner(ctx, callerID, homeID); err != nil {
		return nil, err
	}
	if role != account.RoleOwner && role != account.RoleMember {
		return nil, fmt.Errorf("invalid role %q", role)
	}

	token, err := newInviteToken()
	if err != nil {
		return nil, err
	}

	inv := account.Invitation{
		HomeID:    homeID,
		Email:     email,
		Token:     token,
		Role:      role,
		InvitedBy: &callerID,
		ExpiresAt: s.now().Add(DefaultInvitationTTL),
	}
	return s.repo.CreateInvitation(ctx, inv)
}

func (s *service) AcceptInvitation(ctx context.Context, userID uuid.UUID, token string) (*account.Home, error) {
	inv, err := s.repo.GetInvitationByToken(ctx, token)
	if err != nil {
		return nil, err
	}
	if inv.AcceptedAt != nil {
		return nil, account.ErrInvitationAlreadyAccepted
	}
	if !inv.ExpiresAt.After(s.now()) {
		return nil, account.ErrInvitationExpired
	}

	if err := s.repo.AddMember(ctx, inv.HomeID, userID, inv.Role); err != nil {
		return nil, err
	}
	if err := s.repo.MarkInvitationAccepted(ctx, inv.UUID); err != nil {
		return nil, err
	}
	return s.repo.GetHomeByID(ctx, inv.HomeID)
}

func (s *service) ListMembers(ctx context.Context, callerID, homeID uuid.UUID) ([]account.MemberWithUser, error) {
	if _, err := s.repo.GetMembership(ctx, homeID, callerID); err != nil {
		return nil, err
	}
	return s.repo.ListMembers(ctx, homeID)
}

func (s *service) RemoveMember(ctx context.Context, callerID, homeID, targetID uuid.UUID) error {
	if err := s.requireOwner(ctx, callerID, homeID); err != nil {
		return err
	}

	role, err := s.repo.GetMembership(ctx, homeID, targetID)
	if err != nil {
		return err
	}
	if role == account.RoleOwner {
		owners, err := s.repo.CountOwners(ctx, homeID)
		if err != nil {
			return err
		}
		if owners <= 1 {
			return account.ErrCannotRemoveSoleOwner
		}
	}
	return s.repo.RemoveMember(ctx, homeID, targetID)
}

func (s *service) requireOwner(ctx context.Context, userID, homeID uuid.UUID) error {
	role, err := s.repo.GetMembership(ctx, homeID, userID)
	if err != nil {
		return err
	}
	if role != account.RoleOwner {
		return account.ErrForbidden
	}
	return nil
}

func newInviteToken() (string, error) {
	buf := make([]byte, 32)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(buf), nil
}
