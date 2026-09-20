package auth

import (
	"encoding/json"
	"net/http"
	"strings"

	"github.com/google/uuid"

	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
)

// Headers the edge sets from the validated token. Only HeaderUser is relied on;
// the other two carry claims the edge may or may not be forwarding, and a home
// provisioned without them simply gets a duller name.
const (
	HeaderUser  = "X-User"
	HeaderEmail = "X-User-Email"
	HeaderName  = "X-User-Name"
)

// Middleware resolves the caller the edge asserts and stamps them onto the
// request context. Mount it only on routes the edge has already authenticated.
func Middleware(resolver UserResolver, log logger.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			caller, ok := callerFrom(r)
			if !ok {
				writeError(w, http.StatusUnauthorized, "unauthenticated", "Request carries no authenticated user")
				return
			}

			session, err := resolver.Resolve(r.Context(), caller)
			if err != nil {
				log.Error().Err(err).Str("subject", caller.Subject).Msg("Failed to resolve caller")
				writeError(w, http.StatusInternalServerError, "identity_unresolved", "Failed to resolve the calling user")
				return
			}
			if session.UserID == uuid.Nil || session.HomeID == uuid.Nil {
				log.Error().Str("subject", caller.Subject).Msg("Resolved a caller with no user or no home")
				writeError(w, http.StatusInternalServerError, "identity_unresolved", "Failed to resolve the calling user")
				return
			}

			ctx := WithIdentity(r.Context(), session.UserID, session.HomeID)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// callerFrom reads the identity headers, refusing a request that carries any of
// them more than once. The edge appends its header to whatever the client sent
// rather than replacing it, so a second value means the client supplied one —
// and net/http hands the client's over, which would let any token holder call
// themselves anybody.
func callerFrom(r *http.Request) (Caller, bool) {
	subject, ok := soleHeader(r, HeaderUser)
	if !ok || subject == "" {
		return Caller{}, false
	}

	email, ok := soleHeader(r, HeaderEmail)
	if !ok {
		return Caller{}, false
	}

	name, ok := soleHeader(r, HeaderName)
	if !ok {
		return Caller{}, false
	}

	return Caller{Subject: subject, Email: email, Name: name}, true
}

func soleHeader(r *http.Request, key string) (string, bool) {
	values := r.Header.Values(key)
	if len(values) > 1 {
		return "", false
	}
	if len(values) == 0 {
		return "", true
	}
	return strings.TrimSpace(values[0]), true
}

func writeError(w http.ResponseWriter, statusCode int, code, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)
	json.NewEncoder(w).Encode(map[string]any{
		"error": map[string]string{
			"code":    code,
			"message": message,
		},
	})
}
