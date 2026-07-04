package auth

import (
	"errors"
	"net/http"

	"github.com/google/uuid"

	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
)

// HeaderUser is the edge-set subject header (Kratos identity id or
// client-credentials client id). Set by Oathkeeper on /api/*.
const HeaderUser = "X-User"

// HeaderHome lets a client request a specific home when they belong to
// more than one. Optional; defaults to the user's most-recent membership
// inside UserResolver.Resolve.
const HeaderHome = "X-Home"

// Middleware returns a handler that resolves the X-User subject to a
// (user, home) pair and stamps both onto the request context. It 401s on
// missing header or unknown subject. Mount it only on routes the edge has
// already authenticated (in our case /api/*); /health and /metrics
// short-circuit before it.
func Middleware(resolver UserResolver, log logger.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			subject := r.Header.Get(HeaderUser)
			if subject == "" {
				http.Error(w, "unauthenticated", http.StatusUnauthorized)
				return
			}

			var requested *uuid.UUID
			if h := r.Header.Get(HeaderHome); h != "" {
				id, err := uuid.Parse(h)
				if err != nil {
					http.Error(w, "invalid X-Home", http.StatusBadRequest)
					return
				}
				requested = &id
			}

			user, home, err := resolver.Resolve(r.Context(), subject, requested)
			if err != nil {
				switch {
				case errors.Is(err, ErrUnknownSubject), errors.Is(err, ErrNoMembership):
					http.Error(w, "unauthenticated", http.StatusUnauthorized)
				default:
					log.Error().Err(err).Str("subject", subject).Msg("auth: resolver failed")
					http.Error(w, "internal error", http.StatusInternalServerError)
				}
				return
			}

			ctx := WithIdentity(r.Context(), user.Uuid, home.Uuid)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}
