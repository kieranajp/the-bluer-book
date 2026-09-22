// Package service implements the account operations the auth middleware
// depends on: finding or provisioning the caller, deciding which home their
// request acts on, and who may join or leave that home.
package service

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/kieranajp/the-bluer-book/internal/domain/account"
)

// InvitationTTL is how long an invitation stays redeemable. The database
// decides whether a token is still inside it; this only sets the stamp.
const InvitationTTL = 7 * 24 * time.Hour

// AccountService is the door into the account domain.
type AccountService interface {
	// ProvisionFromSubject returns the user behind a token subject, creating
	// them, a home and their ownership of it the first time that subject is
	// seen.
	ProvisionFromSubject(ctx context.Context, id account.Identity) (account.User, error)

	// FindUser returns a user by their own id.
	FindUser(ctx context.Context, userID uuid.UUID) (account.User, error)

	// ResolveActiveHome returns the home a request acts on. A requested home is
	// returned only to a member of it; uuid.Nil asks for the one the user most
	// recently joined.
	ResolveActiveHome(ctx context.Context, user account.User, requested uuid.UUID) (account.Home, error)

	// ListHomes returns the homes the user belongs to and their standing in
	// each.
	ListHomes(ctx context.Context, userID uuid.UUID) ([]account.Membership, error)

	// Invite creates an invitation to a home and returns it alongside the token
	// that redeems it. Only an owner may invite. The token is returned once and
	// is not recoverable afterwards.
	Invite(ctx context.Context, actorID, homeID uuid.UUID, email string, role account.Role) (account.Invitation, string, error)

	// AcceptInvitation redeems a token, putting the caller in the home it names
	// and spending the token.
	AcceptInvitation(ctx context.Context, userID uuid.UUID, token string) (account.Home, account.Role, error)

	// ListMembers returns everyone in a home. Only a member may ask.
	ListMembers(ctx context.Context, actorID, homeID uuid.UUID) ([]account.Member, error)

	// RemoveMember takes somebody out of a home. Only an owner may, and not the
	// last owner.
	RemoveMember(ctx context.Context, actorID, homeID, targetID uuid.UUID) error
}

type accountService struct {
	repo  account.Repository
	probe account.Probe

	// founderSubject is the operator's subject. It attaches to the home that
	// already holds the recipes rather than to a fresh one. Empty means nobody
	// gets that treatment.
	founderSubject string

	now func() time.Time
}

func NewAccountService(repo account.Repository, founderSubject string, probe account.Probe) AccountService {
	return &accountService{repo: repo, probe: probe, founderSubject: founderSubject, now: time.Now}
}

func (s *accountService) ProvisionFromSubject(ctx context.Context, id account.Identity) (account.User, error) {
	if id.Subject == "" {
		return account.User{}, errors.New("account: cannot provision without a subject")
	}

	user, err := s.repo.FindUserBySubject(ctx, id.Subject)
	if err == nil {
		return s.refreshed(ctx, user, id), nil
	}
	if !errors.Is(err, account.ErrUserNotFound) {
		s.probe.AccountError("find_user", err)
		return account.User{}, err
	}

	user, _, err = s.repo.ProvisionUser(ctx, id, s.homeTarget(id))
	if err != nil {
		s.probe.AccountError("provision_user", err)
		return account.User{}, err
	}
	s.probe.UserProvisioned(id.Subject)
	return user, nil
}

// refreshed keeps the stored email and display name level with the claims the
// edge is forwarding, which is what the rest of a home sees in the member list.
// A failed refresh is not worth failing the request over: the caller resolves
// either way and their profile stays a request behind.
func (s *accountService) refreshed(ctx context.Context, user account.User, id account.Identity) account.User {
	if !profileMoved(user, id) {
		return user
	}

	updated, err := s.repo.RefreshProfile(ctx, id)
	if err != nil {
		s.probe.AccountError("refresh_profile", err)
		return user
	}
	return updated
}

// profileMoved ignores a claim that did not arrive: an absent email is the edge
// forwarding nothing, not a user who has given theirs up.
func profileMoved(user account.User, id account.Identity) bool {
	return (id.Email != "" && id.Email != user.Email) ||
		(id.DisplayName != "" && id.DisplayName != user.DisplayName)
}

func (s *accountService) FindUser(ctx context.Context, userID uuid.UUID) (account.User, error) {
	user, err := s.repo.FindUserByID(ctx, userID)
	if err != nil && !errors.Is(err, account.ErrUserNotFound) {
		s.probe.AccountError("find_user", err)
	}
	return user, err
}

func (s *accountService) ResolveActiveHome(ctx context.Context, user account.User, requested uuid.UUID) (account.Home, error) {
	// A client naming a home is naming one it may have no business in, so this
	// branch falls back to nothing. Dropping through to the most recent home
	// would answer a different question than the one asked, and provisioning a
	// fresh one would hand a stranger a 200 and an empty book.
	if requested != uuid.Nil {
		home, err := s.repo.FindHomeForUser(ctx, user.UUID, requested)
		if err != nil && !errors.Is(err, account.ErrHomeNotFound) {
			s.probe.AccountError("find_home", err)
		}
		return home, err
	}

	home, err := s.repo.FindMostRecentHome(ctx, user.UUID)
	if err == nil {
		return home, nil
	}
	if !errors.Is(err, account.ErrHomeNotFound) {
		s.probe.AccountError("find_home", err)
		return account.Home{}, err
	}

	// A known user with no home has lost their last membership.
	id := account.Identity{Subject: user.Subject, Email: user.Email, DisplayName: user.DisplayName}
	_, home, err = s.repo.ProvisionUser(ctx, id, s.homeTarget(id))
	if err != nil {
		s.probe.AccountError("provision_home", err)
	}
	return home, err
}

func (s *accountService) ListHomes(ctx context.Context, userID uuid.UUID) ([]account.Membership, error) {
	homes, err := s.repo.ListHomesForUser(ctx, userID)
	if err != nil {
		s.probe.AccountError("list_homes", err)
	}
	return homes, err
}

func (s *accountService) Invite(ctx context.Context, actorID, homeID uuid.UUID, email string, role account.Role) (account.Invitation, string, error) {
	// Standing is checked before the body is, so a non-owner learns only that
	// they may not invite — never whether their request was otherwise good.
	if err := s.requireOwner(ctx, homeID, actorID); err != nil {
		return account.Invitation{}, "", err
	}

	if role == "" {
		role = account.RoleMember
	}
	if !role.Valid() {
		return account.Invitation{}, "", account.ErrInvalidRole
	}
	email = strings.TrimSpace(email)
	if email == "" {
		return account.Invitation{}, "", account.ErrEmailRequired
	}

	token, hash, err := account.NewInvitationToken()
	if err != nil {
		s.probe.AccountError("new_token", err)
		return account.Invitation{}, "", err
	}

	inv, err := s.repo.CreateInvitation(ctx, account.Invitation{
		HomeID:    homeID,
		Email:     email,
		Role:      role,
		InvitedBy: actorID,
		ExpiresAt: s.now().Add(InvitationTTL),
	}, hash)
	if err != nil {
		s.probe.AccountError("create_invitation", err)
		return account.Invitation{}, "", err
	}

	s.probe.MembershipChanged("invited", homeID)
	return inv, token, nil
}

func (s *accountService) AcceptInvitation(ctx context.Context, userID uuid.UUID, token string) (account.Home, account.Role, error) {
	token = strings.TrimSpace(token)
	if token == "" {
		s.probe.InvitationRefused("empty")
		return account.Home{}, "", account.ErrInvitationNotFound
	}

	// Expiry and single use are the database's to decide, in the one statement
	// that spends the token. Deciding either here would mean reading the row
	// first, and two requests reading it together would both be allowed in.
	home, role, err := s.repo.RedeemInvitation(ctx, account.HashInvitationToken(token), userID)
	switch {
	case err == nil:
		s.probe.MembershipChanged("joined", home.UUID)
		return home, role, nil
	case errors.Is(err, account.ErrInvitationNotFound):
		s.probe.InvitationRefused("unknown")
	case errors.Is(err, account.ErrInvitationExpired):
		s.probe.InvitationRefused("expired")
	case errors.Is(err, account.ErrInvitationUsed):
		s.probe.InvitationRefused("used")
	default:
		s.probe.AccountError("redeem_invitation", err)
	}
	return account.Home{}, "", err
}

func (s *accountService) ListMembers(ctx context.Context, actorID, homeID uuid.UUID) ([]account.Member, error) {
	if _, err := s.repo.FindRole(ctx, homeID, actorID); err != nil {
		return nil, err
	}

	members, err := s.repo.ListMembers(ctx, homeID)
	if err != nil {
		s.probe.AccountError("list_members", err)
	}
	return members, err
}

func (s *accountService) RemoveMember(ctx context.Context, actorID, homeID, targetID uuid.UUID) error {
	if err := s.requireOwner(ctx, homeID, actorID); err != nil {
		return err
	}

	// Whether this is the last owner is settled inside the repository, under a
	// lock on the home. Asking here and acting on the answer would let two
	// owners be removed at once, each counting the other.
	if err := s.repo.RemoveMember(ctx, homeID, targetID); err != nil {
		if !errors.Is(err, account.ErrLastOwner) && !errors.Is(err, account.ErrMemberNotFound) {
			s.probe.AccountError("remove_member", err)
		}
		return err
	}

	s.probe.MembershipChanged("removed", homeID)
	return nil
}

// requireOwner refuses anybody who is not an owner of the home, including
// everybody who is not in it at all.
func (s *accountService) requireOwner(ctx context.Context, homeID, userID uuid.UUID) error {
	role, err := s.repo.FindRole(ctx, homeID, userID)
	if err != nil {
		return err
	}
	if role != account.RoleOwner {
		return account.ErrForbidden
	}
	return nil
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
