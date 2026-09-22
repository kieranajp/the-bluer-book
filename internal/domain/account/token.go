package account

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"fmt"
)

// NewInvitationToken returns a fresh token and the hash a row stores; the
// token itself is never recoverable from the database again.
func NewInvitationToken() (token, hash string, err error) {
	buf := make([]byte, 32)
	if _, err := rand.Read(buf); err != nil {
		return "", "", fmt.Errorf("account: reading random bytes for an invitation token: %w", err)
	}
	token = base64.RawURLEncoding.EncodeToString(buf)
	return token, HashInvitationToken(token), nil
}

// HashInvitationToken maps a token onto the value stored against it. Hashing
// matters because the invitations table sits outside row-level security.
func HashInvitationToken(token string) string {
	sum := sha256.Sum256([]byte(token))
	return hex.EncodeToString(sum[:])
}
