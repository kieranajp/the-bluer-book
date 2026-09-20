package account

import "errors"

var (
	// ErrUserNotFound means no user holds the given subject.
	ErrUserNotFound = errors.New("user not found")

	// ErrHomeNotFound means the home does not exist, or the user has no
	// membership of it.
	ErrHomeNotFound = errors.New("home not found")

	// ErrMemberNotFound means the named user is not in the home.
	ErrMemberNotFound = errors.New("member not found")

	// ErrForbidden means the caller may not do this here. Not being a member of
	// the home at all lands here too: whether a home exists is not a
	// non-member's to learn.
	ErrForbidden = errors.New("forbidden")

	// ErrLastOwner means the removal would leave a home with no owner, and so
	// nobody who could invite anyone or remove anyone.
	ErrLastOwner = errors.New("cannot remove a home's last owner")

	// ErrInvalidRole means the requested role is not one this application has.
	ErrInvalidRole = errors.New("invalid role")

	// ErrEmailRequired means an invitation named nobody to send it to.
	ErrEmailRequired = errors.New("invitation email is required")

	// ErrInvitationNotFound means no invitation matches the token.
	ErrInvitationNotFound = errors.New("invitation not found")

	// ErrInvitationExpired means the token was good and is past its expiry.
	ErrInvitationExpired = errors.New("invitation expired")

	// ErrInvitationUsed means the token has already been redeemed. An
	// invitation is good once.
	ErrInvitationUsed = errors.New("invitation already accepted")
)
