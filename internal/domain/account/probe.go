package account

import "github.com/google/uuid"

// Probe provides domain-oriented observability for account operations.
type Probe interface {
	UserProvisioned(subject string)
	MembershipChanged(action string, homeID uuid.UUID)
	// InvitationRefused counts tokens that were presented and not honoured.
	// A run of these is somebody working through guesses, or a client holding
	// a token it should have discarded; either is worth seeing.
	InvitationRefused(reason string)
	AccountError(operation string, err error)
}
