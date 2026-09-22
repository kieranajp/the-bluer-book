package auth

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"github.com/google/uuid"

	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
)

// Headers the edge sets from the validated token. Only HeaderUser is relied
// on; the others are optional claims.
const (
	HeaderUser  = "X-User"
	HeaderEmail = "X-User-Email"
	HeaderName  = "X-User-Name"
)

// HeaderHome is client-supplied, not edge-asserted: the resolver returns the
// home only to a member of it. Absent means the most recently joined home.
const HeaderHome = "X-Home"

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

			home, ok := requestedHome(r)
			if !ok {
				writeError(w, http.StatusBadRequest, "invalid_home", "X-Home is not a home id")
				return
			}
			caller.Home = home

			session, err := resolver.Resolve(r.Context(), caller)
			if errors.Is(err, ErrHomeForbidden) {
				log.Warn().Str("subject", caller.Subject).Str("home", home.String()).Msg("Caller named a home they are not in")
				// Its own status, because the client answers 401 by refreshing
				// and replaying — a valid session burnt on a stale home.
				writeError(w, http.StatusForbidden, "home_forbidden", "Caller is not a member of the requested home")
				return
			}
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

// requestedHome treats an absent or empty X-Home as no request, not a
// failure; anything present must parse to a valid, non-nil id.
func requestedHome(r *http.Request) (uuid.UUID, bool) {
	value, ok := soleHeader(r, HeaderHome)
	if !ok {
		return uuid.Nil, false
	}
	if value == "" {
		return uuid.Nil, true
	}

	home, err := uuid.Parse(value)
	if err != nil || home == uuid.Nil {
		return uuid.Nil, false
	}
	return home, true
}

// soleHeader refuses a header sent twice: the edge appends to whatever the
// client sent rather than replacing it, so a second value is client forgery.
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
