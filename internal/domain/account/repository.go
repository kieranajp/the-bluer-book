package account

import (
	"context"

	"github.com/google/uuid"
)

// HomeTarget says where a provisioned user lands. A set ID joins that existing
// home; otherwise a home called Name is created for them.
type HomeTarget struct {
	ID   uuid.UUID
	Name string
}

// Repository is the persistence port for accounts. The adapter lives in
// infrastructure/storage/repository; the port sits here so the service depends
// on the domain alone and the auth middleware can sit upstream of both.
type Repository interface {
	// FindUserBySubject returns the user holding a token subject, or
	// ErrUserNotFound.
	FindUserBySubject(ctx context.Context, subject string) (User, error)

	// FindUserByID returns a user by their own id, or ErrUserNotFound.
	FindUserByID(ctx context.Context, userID uuid.UUID) (User, error)

	// FindMostRecentHome returns the home the user most recently joined, or
	// ErrHomeNotFound when they belong to none.
	FindMostRecentHome(ctx context.Context, userID uuid.UUID) (Home, error)

	// FindHomeForUser returns a named home, and returns ErrHomeNotFound unless
	// the user is a member of it. This is what stands between a client naming
	// any home it likes and that home's data.
	FindHomeForUser(ctx context.Context, userID, homeID uuid.UUID) (Home, error)

	// ListHomesForUser returns every home the user belongs to, most recently
	// joined first.
	ListHomesForUser(ctx context.Context, userID uuid.UUID) ([]Membership, error)

	// ProvisionUser gives a caller a user row, a home and an owner membership of
	// it, in one transaction. It is idempotent: a user who already exists keeps
	// their identity and their existing home, so concurrent first requests for
	// one subject settle on the same pair.
	ProvisionUser(ctx context.Context, id Identity, target HomeTarget) (User, Home, error)

	// FindRole returns the caller's standing in a home, or ErrForbidden when
	// they have none.
	FindRole(ctx context.Context, homeID, userID uuid.UUID) (Role, error)

	// ListMembers returns everyone in a home, longest-standing first.
	ListMembers(ctx context.Context, homeID uuid.UUID) ([]Member, error)

	// CreateInvitation stores an invitation against the hash of its token. The
	// token itself never reaches this layer.
	CreateInvitation(ctx context.Context, inv Invitation, tokenHash string) (Invitation, error)

	// RedeemInvitation spends the invitation matching tokenHash and puts userID
	// in its home, in one transaction: an invitation that admits somebody is
	// always spent, and a spent one admits nobody a second time. It returns the
	// home joined and the role held there, or ErrInvitationNotFound,
	// ErrInvitationExpired or ErrInvitationUsed.
	RedeemInvitation(ctx context.Context, tokenHash string, userID uuid.UUID) (Home, Role, error)

	// RemoveMember takes a user out of a home, refusing with ErrLastOwner when
	// they are the only owner left.
	RemoveMember(ctx context.Context, homeID, userID uuid.UUID) error
}
