package account

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"fmt"
)

// NewInvitationToken returns a fresh invitation token and the hash a row stores
// for it. The caller hands the token to the invitee and keeps nothing: the
// token is never recoverable from the database again.
func NewInvitationToken() (token, hash string, err error) {
	buf := make([]byte, 32)
	if _, err := rand.Read(buf); err != nil {
		return "", "", fmt.Errorf("account: reading random bytes for an invitation token: %w", err)
	}
	token = base64.RawURLEncoding.EncodeToString(buf)
	return token, HashInvitationToken(token), nil
}

// HashInvitationToken maps a token onto the value stored against it.
//
// A plain SHA-256 is the right hash here, where it would be wrong for a
// password: the token is 256 bits from crypto/rand, so there is no guessing
// attack for a work factor to slow down and no reused secret for a salt to
// separate. What the hash buys is that reading the invitations table — which
// sits outside row-level security, because a token is looked up before either
// party's home is known — does not let anybody redeem anything.
func HashInvitationToken(token string) string {
	sum := sha256.Sum256([]byte(token))
	return hex.EncodeToString(sum[:])
}
