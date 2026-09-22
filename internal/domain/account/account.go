// Package account models the people using the book and the homes they keep
// it in. Nothing here carries a home_id.
package account

import (
	"time"

	"github.com/google/uuid"
)

// FounderHomeID holds the collection predating multitenancy; the operator's
// subject attaches to it on first login rather than getting a fresh one.
var FounderHomeID = uuid.MustParse("00000000-0000-0000-0000-000000000001")

// Role is a user's standing in a home. The user a home is provisioned for owns
// it.
type Role string

const (
	RoleOwner  Role = "owner"
	RoleMember Role = "member"
)

// Identity is what the edge knows about a caller. Only Subject is guaranteed.
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

// Membership is a home together with the standing its holder has in it.
type Membership struct {
	Home Home
	Role Role
}

// Member is one person in a home, and what they may do there.
type Member struct {
	User User
	Role Role
}

// Invitation is an outstanding offer of membership. Only its token's hash is
// stored, so a copy of this row joins nobody to anything.
type Invitation struct {
	UUID      uuid.UUID
	HomeID    uuid.UUID
	Email     string
	Role      Role
	InvitedBy uuid.UUID
	ExpiresAt time.Time
	CreatedAt time.Time
}

// Valid reports whether a role is one this application recognises. A role
// arrives from a request body, so nothing may assume it does.
func (r Role) Valid() bool {
	return r == RoleOwner || r == RoleMember
}
