package account

import "errors"

var (
	// ErrUserNotFound means no user holds the given subject.
	ErrUserNotFound = errors.New("user not found")

	// ErrHomeNotFound means the home does not exist, or the user has no
	// membership of it.
	ErrHomeNotFound = errors.New("home not found")
)
