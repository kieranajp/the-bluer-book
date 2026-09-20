package auth

import (
	"encoding/json"
	"net/http"
	"strings"

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
// request context. Mount it only on routes the edge has already authenticated:
// it takes X-User entirely on trust, so anything that reaches the server around
// the edge is whoever it claims to be.
func Middleware(resolver UserResolver, log logger.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			caller := Caller{
				Subject: strings.TrimSpace(r.Header.Get(HeaderUser)),
				Email:   strings.TrimSpace(r.Header.Get(HeaderEmail)),
				Name:    strings.TrimSpace(r.Header.Get(HeaderName)),
			}

			if caller.Subject == "" {
				writeError(w, http.StatusUnauthorized, "unauthenticated", "Request carries no authenticated user")
				return
			}

			session, err := resolver.Resolve(r.Context(), caller)
			if err != nil {
				log.Error().Err(err).Str("subject", caller.Subject).Msg("Failed to resolve caller")
				writeError(w, http.StatusInternalServerError, "identity_unresolved", "Failed to resolve the calling user")
				return
			}

			ctx := WithIdentity(r.Context(), session.UserID, session.HomeID)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
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
