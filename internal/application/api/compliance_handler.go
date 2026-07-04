package api

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/kieranajp/the-bluer-book/internal/application/compliance"
	"github.com/kieranajp/the-bluer-book/internal/domain/account"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/auth"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
)

// ComplianceHandler exposes the Google-Play-mandated
// account-deletion + data-export endpoints, plus the public web URL
// for users without the app.
type ComplianceHandler struct {
	svc    compliance.Service
	logger logger.Logger
}

func NewComplianceHandler(svc compliance.Service, log logger.Logger) *ComplianceHandler {
	return &ComplianceHandler{svc: svc, logger: log}
}

// DELETE /api/account
//
// Authenticated. Removes the user from the local database; if the user
// is the sole owner of a home, the home and all its data are purged in
// the same call. The body returns a summary so the client can confirm
// which homes were affected.
func (h *ComplianceHandler) DeleteAccount(w http.ResponseWriter, r *http.Request) {
	userID, ok := auth.UserID(r.Context())
	if !ok {
		writeAPIError(w, http.StatusUnauthorized, "unauthenticated", "missing user identity")
		return
	}

	result, err := h.svc.DeleteAccount(r.Context(), userID)
	if err != nil {
		h.writeServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, result)
}

// GET /api/account/export
//
// Returns the active home's data as a JSON document for the Google
// Play data-portability requirement. Owner-only on shared homes (see
// compliance.Service.ExportData).
func (h *ComplianceHandler) ExportData(w http.ResponseWriter, r *http.Request) {
	userID, ok := auth.UserID(r.Context())
	if !ok {
		writeAPIError(w, http.StatusUnauthorized, "unauthenticated", "missing user identity")
		return
	}
	homeID, ok := auth.HomeID(r.Context())
	if !ok {
		writeAPIError(w, http.StatusBadRequest, "no_active_home", "no active home")
		return
	}

	payload, err := h.svc.ExportData(r.Context(), userID, homeID)
	if err != nil {
		h.writeServiceError(w, err)
		return
	}

	// Encourage browsers to offer "save as" rather than render in tab.
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Content-Disposition", `attachment; filename="bluer-book-export.json"`)
	_ = json.NewEncoder(w).Encode(payload)
}

func (h *ComplianceHandler) writeServiceError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, account.ErrForbidden):
		writeAPIError(w, http.StatusForbidden, "forbidden", "you are not allowed to perform this action")
	case errors.Is(err, account.ErrHomeNotFound):
		writeAPIError(w, http.StatusNotFound, "home_not_found", "home not found")
	case errors.Is(err, account.ErrUserNotFound):
		writeAPIError(w, http.StatusNotFound, "user_not_found", "user not found")
	default:
		h.logger.Error().Err(err).Msg("compliance handler: unexpected error")
		writeAPIError(w, http.StatusInternalServerError, "internal", "internal error")
	}
}
