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

// AdminRepository is the destructive subset of account persistence,
// kept separate because its impl must run on an owner-role connection
// (RLS and FORCE bites the app role when cascading across homes).
// Compliance flows — account deletion in particular — depend on it.
type AdminRepository interface {
	PurgeHome(ctx context.Context, homeID uuid.UUID) error
	DeleteUser(ctx context.Context, userID uuid.UUID) error
}

// IdentityDeleter is the port for the upstream IdP's "delete this
// identity" admin call (Kratos in our case). The Phase 0 Terraform
// stack provides the admin URL; until that lands, the wired impl is a
// no-op so the deletion flow doesn't 500 in dev.
type IdentityDeleter interface {
	Delete(ctx context.Context, subject string) error
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
