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

	// FindMostRecentHome returns the home the user most recently joined, or
	// ErrHomeNotFound when they belong to none.
	FindMostRecentHome(ctx context.Context, userID uuid.UUID) (Home, error)

	// ProvisionUser gives a caller a user row, a home and an owner membership of
	// it, in one transaction. It is idempotent: a user who already exists keeps
	// their identity and their existing home, so concurrent first requests for
	// one subject settle on the same pair.
	ProvisionUser(ctx context.Context, id Identity, target HomeTarget) (User, Home, error)
}
