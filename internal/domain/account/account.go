// Package account models user identities, homes (households), home
// memberships, and invitations. It's the resolution layer that sits
// alongside (and slightly outside) the per-home tenant data — these
// tables don't carry home_id and aren't under RLS, because they need to
// run before a home is established for a given request.
package account

import (
	"time"

	"github.com/google/uuid"
)

// Role names a user's permission level within a Home. Owners can invite,
// remove members, and (Phase 6) delete the home; members can read/write
// the home's data but not change membership.
type Role string

const (
	RoleOwner  Role = "owner"
	RoleMember Role = "member"
)

// User is the canonical account record for a person. Subject is the
// stable identifier issued by the upstream IdP (Kratos identity id when
// going through the Ory edge); we never store passwords.
type User struct {
	UUID        uuid.UUID
	Subject     string
	Email       string
	DisplayName string
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

// Home is a household — the multi-user workspace that owns recipes,
// meal plans, photos and per-home ingredient vocabulary.
type Home struct {
	UUID      uuid.UUID
	Name      string
	CreatedAt time.Time
	UpdatedAt time.Time
}

// Membership pairs a User with a Home and the User's Role in it. A user
// can belong to multiple homes; the active one for a request is chosen
// by an explicit X-Home header or the most-recent membership.
type Membership struct {
	Home Home
	Role Role
}

// Invitation is an outstanding invite to join a Home. Token is the
// opaque value sent to the invitee; redemption flips AcceptedAt and
// creates the matching home_members row.
type Invitation struct {
	UUID       uuid.UUID
	HomeID     uuid.UUID
	Email      string
	Token      string
	Role       Role
	InvitedBy  *uuid.UUID
	AcceptedAt *time.Time
	ExpiresAt  time.Time
	CreatedAt  time.Time
}
