// Package account models the people using the book and the homes they keep it
// in. It resolves a request before any home is known, so nothing here carries a
// home_id.
package account

import (
	"time"

	"github.com/google/uuid"
)

// FounderHomeID is the home migration 00011 creates for the collection that
// predates multitenancy. The operator's subject attaches to it on first login
// rather than getting a fresh, empty one.
var FounderHomeID = uuid.MustParse("00000000-0000-0000-0000-000000000001")

// Role is a user's standing in a home. The user a home is provisioned for owns
// it.
type Role string

const (
	RoleOwner  Role = "owner"
	RoleMember Role = "member"
)

// Identity is what the edge knows about a caller: the token subject, plus the
// email and name claims when the edge is configured to forward them. Only
// Subject is guaranteed.
type Identity struct {
	Subject     string
	Email       string
	DisplayName string
}

// User is a person. Subject is the identity provider's stable, opaque
// identifier for them; no credential of theirs is stored here.
type User struct {
	UUID        uuid.UUID
	Subject     string
	Email       string
	DisplayName string
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

// Home is a household: the unit that owns recipes, meal plans and a pantry, and
// the unit a request is scoped to.
type Home struct {
	UUID      uuid.UUID
	Name      string
	CreatedAt time.Time
	UpdatedAt time.Time
}
