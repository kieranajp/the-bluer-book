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

// Repository is the persistence port for accounts.
type Repository interface {
	// FindUserBySubject returns the user holding a token subject, or
	// ErrUserNotFound.
	FindUserBySubject(ctx context.Context, subject string) (User, error)

	// FindUserByID returns a user by their own id, or ErrUserNotFound.
	FindUserByID(ctx context.Context, userID uuid.UUID) (User, error)

	// FindMostRecentHome returns the home the user most recently joined, or
	// ErrHomeNotFound when they belong to none.
	FindMostRecentHome(ctx context.Context, userID uuid.UUID) (Home, error)

	// FindHomeForUser returns ErrHomeNotFound unless the user is a member of
	// the home, so a client can't name its way into another home's data.
	FindHomeForUser(ctx context.Context, userID, homeID uuid.UUID) (Home, error)

	// ListHomesForUser returns every home the user belongs to, most recently
	// joined first.
	ListHomesForUser(ctx context.Context, userID uuid.UUID) ([]Membership, error)

	// ProvisionUser is idempotent: a user who already exists keeps their
	// identity and home, so concurrent first requests settle on the same pair.
	ProvisionUser(ctx context.Context, id Identity, target HomeTarget) (User, Home, error)

	// RefreshProfile leaves stored fields as they are wherever the identity
	// carries an empty value.
	RefreshProfile(ctx context.Context, id Identity) (User, error)

	// FindRole returns the caller's standing in a home, or ErrForbidden when
	// they have none.
	FindRole(ctx context.Context, homeID, userID uuid.UUID) (Role, error)

	// ListMembers returns everyone in a home, longest-standing first.
	ListMembers(ctx context.Context, homeID uuid.UUID) ([]Member, error)

	// CreateInvitation stores an invitation against the hash of its token. The
	// token itself never reaches this layer.
	CreateInvitation(ctx context.Context, inv Invitation, tokenHash string) (Invitation, error)

	// RedeemInvitation spends the token and admits userID in one transaction,
	// so a spent invitation can never admit twice.
	RedeemInvitation(ctx context.Context, tokenHash string, userID uuid.UUID) (Home, Role, error)

	// RemoveMember takes a user out of a home, refusing with ErrLastOwner when
	// they are the only owner left.
	RemoveMember(ctx context.Context, homeID, userID uuid.UUID) error
}
