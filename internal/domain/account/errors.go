package account

import "errors"

var (
	// ErrUserNotFound is returned when no user matches the given key.
	ErrUserNotFound = errors.New("user not found")

	// ErrHomeNotFound is returned when the home doesn't exist or the
	// caller has no membership in it.
	ErrHomeNotFound = errors.New("home not found")

	// ErrInvitationNotFound is returned when an invitation token doesn't
	// match an outstanding invite (or has been redeemed/expired already).
	ErrInvitationNotFound = errors.New("invitation not found")

	// ErrInvitationExpired is returned when the invitation token is past
	// its expiry.
	ErrInvitationExpired = errors.New("invitation expired")

	// ErrInvitationAlreadyAccepted is returned when the token has already
	// been redeemed.
	ErrInvitationAlreadyAccepted = errors.New("invitation already accepted")

	// ErrForbidden is returned when the caller is not allowed to perform
	// the operation — most often a non-owner trying to invite or remove
	// members.
	ErrForbidden = errors.New("forbidden")

	// ErrCannotRemoveSoleOwner is returned when an attempt is made to
	// remove the last owner of a home. The caller should delete the home
	// instead (Phase 6).
	ErrCannotRemoveSoleOwner = errors.New("cannot remove the sole owner of a home")
)
