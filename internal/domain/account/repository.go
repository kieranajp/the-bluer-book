package account

import (
	"context"

	"github.com/google/uuid"
)

// MemberWithUser pairs a User with their Role inside a single home.
// Used by the members-listing port.
type MemberWithUser struct {
	User User
	Role Role
}

// Repository is the persistence port for the account domain. The
// concrete adapter lives in internal/infrastructure/storage/repository;
// this interface lets the service depend on the domain layer alone, so
// the auth middleware can sit upstream of both without an import cycle.
type Repository interface {
	GetUserBySubject(ctx context.Context, subject string) (*User, error)
	GetUserByUUID(ctx context.Context, id uuid.UUID) (*User, error)
	CreateUser(ctx context.Context, subject, email, displayName string) (*User, error)

	CreateHome(ctx context.Context, name string) (*Home, error)
	GetHomeByID(ctx context.Context, id uuid.UUID) (*Home, error)
	GetHomeForUserByID(ctx context.Context, userID, homeID uuid.UUID) (*Home, error)
	GetMostRecentHomeForUser(ctx context.Context, userID uuid.UUID) (*Home, error)
	ListHomesForUser(ctx context.Context, userID uuid.UUID) ([]Membership, error)

	AddMember(ctx context.Context, homeID, userID uuid.UUID, role Role) error
	RemoveMember(ctx context.Context, homeID, userID uuid.UUID) error
	GetMembership(ctx context.Context, homeID, userID uuid.UUID) (Role, error)
	ListMembers(ctx context.Context, homeID uuid.UUID) ([]MemberWithUser, error)
	CountOwners(ctx context.Context, homeID uuid.UUID) (int, error)

	CreateInvitation(ctx context.Context, inv Invitation) (*Invitation, error)
	GetInvitationByToken(ctx context.Context, token string) (*Invitation, error)
	MarkInvitationAccepted(ctx context.Context, invitationID uuid.UUID) error
	ListInvitations(ctx context.Context, homeID uuid.UUID) ([]Invitation, error)
}
