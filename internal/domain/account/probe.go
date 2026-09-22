package account

import "github.com/google/uuid"

// Probe provides domain-oriented observability for account operations.
type Probe interface {
	UserProvisioned(subject string)
	MembershipChanged(action string, homeID uuid.UUID)
	// InvitationRefused counts tokens presented and not honoured: a run of
	// these is guessing, or a client holding a token it should have discarded.
	InvitationRefused(reason string)
	AccountError(operation string, err error)
}
