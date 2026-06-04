package api

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"github.com/google/uuid"

	"github.com/kieranajp/the-bluer-book/internal/domain/account"
	accountservice "github.com/kieranajp/the-bluer-book/internal/domain/account/service"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/auth"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
)

type AccountHandler struct {
	svc    accountservice.Service
	logger logger.Logger
}

func NewAccountHandler(svc accountservice.Service, log logger.Logger) *AccountHandler {
	return &AccountHandler{svc: svc, logger: log}
}

// GET /api/me — current user + the homes they belong to + which one is
// active for this request. Lets the Flutter app render a workspace
// switcher and figure out where it just landed.
func (h *AccountHandler) Me(w http.ResponseWriter, r *http.Request) {
	userID, ok := auth.UserID(r.Context())
	if !ok {
		writeAPIError(w, http.StatusUnauthorized, "unauthenticated", "missing user identity")
		return
	}
	activeHomeID, _ := auth.HomeID(r.Context())

	memberships, err := h.svc.ListHomesForUser(r.Context(), userID)
	if err != nil {
		h.logger.Error().Err(err).Msg("ListHomesForUser failed")
		writeAPIError(w, http.StatusInternalServerError, "internal", "failed to load homes")
		return
	}

	homes := make([]map[string]any, len(memberships))
	for i, m := range memberships {
		homes[i] = map[string]any{
			"uuid": m.Home.UUID,
			"name": m.Home.Name,
			"role": string(m.Role),
		}
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"active_home_id": activeHomeID,
		"homes":          homes,
	})
}

// POST /api/homes/{id}/invitations
//
//	{"email": "...", "role": "owner|member"}
//
// Returns the created invitation with its token. The Flutter app turns
// the token into a shareable accept-link.
func (h *AccountHandler) CreateInvitation(w http.ResponseWriter, r *http.Request) {
	callerID, ok := requireUser(w, r)
	if !ok {
		return
	}
	homeID, ok := homeIDFromPath(w, r)
	if !ok {
		return
	}

	var body struct {
		Email string `json:"email"`
		Role  string `json:"role"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeAPIError(w, http.StatusBadRequest, "invalid_body", "invalid JSON body")
		return
	}
	body.Email = strings.TrimSpace(body.Email)
	if body.Email == "" {
		writeAPIError(w, http.StatusBadRequest, "email_required", "email is required")
		return
	}
	role := account.Role(body.Role)
	if role == "" {
		role = account.RoleMember
	}

	inv, err := h.svc.InviteToHome(r.Context(), callerID, homeID, body.Email, role)
	if err != nil {
		h.writeServiceError(w, err)
		return
	}

	writeJSON(w, http.StatusCreated, invitationView(inv))
}

// POST /api/invitations/{token}/accept
func (h *AccountHandler) AcceptInvitation(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUser(w, r)
	if !ok {
		return
	}
	token := r.PathValue("token")
	if token == "" {
		writeAPIError(w, http.StatusBadRequest, "missing_token", "token is required")
		return
	}

	home, err := h.svc.AcceptInvitation(r.Context(), userID, token)
	if err != nil {
		h.writeServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"home_id": home.UUID,
		"name":    home.Name,
	})
}

// GET /api/homes/{id}/members
func (h *AccountHandler) ListMembers(w http.ResponseWriter, r *http.Request) {
	callerID, ok := requireUser(w, r)
	if !ok {
		return
	}
	homeID, ok := homeIDFromPath(w, r)
	if !ok {
		return
	}

	members, err := h.svc.ListMembers(r.Context(), callerID, homeID)
	if err != nil {
		h.writeServiceError(w, err)
		return
	}

	out := make([]map[string]any, len(members))
	for i, m := range members {
		out[i] = map[string]any{
			"user_id":      m.User.UUID,
			"email":        m.User.Email,
			"display_name": m.User.DisplayName,
			"role":         string(m.Role),
		}
	}
	writeJSON(w, http.StatusOK, map[string]any{"members": out})
}

// DELETE /api/homes/{id}/members/{userID}
func (h *AccountHandler) RemoveMember(w http.ResponseWriter, r *http.Request) {
	callerID, ok := requireUser(w, r)
	if !ok {
		return
	}
	homeID, ok := homeIDFromPath(w, r)
	if !ok {
		return
	}
	targetID, err := uuid.Parse(r.PathValue("userID"))
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, "invalid_user_id", "invalid user ID")
		return
	}

	if err := h.svc.RemoveMember(r.Context(), callerID, homeID, targetID); err != nil {
		h.writeServiceError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// Helpers.

func requireUser(w http.ResponseWriter, r *http.Request) (uuid.UUID, bool) {
	id, ok := auth.UserID(r.Context())
	if !ok {
		writeAPIError(w, http.StatusUnauthorized, "unauthenticated", "missing user identity")
		return uuid.Nil, false
	}
	return id, true
}

func homeIDFromPath(w http.ResponseWriter, r *http.Request) (uuid.UUID, bool) {
	id, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, "invalid_home_id", "invalid home ID")
		return uuid.Nil, false
	}
	return id, true
}

func (h *AccountHandler) writeServiceError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, account.ErrForbidden):
		writeAPIError(w, http.StatusForbidden, "forbidden", "you are not allowed to perform this action")
	case errors.Is(err, account.ErrInvitationNotFound):
		writeAPIError(w, http.StatusNotFound, "invitation_not_found", "invitation not found or already used")
	case errors.Is(err, account.ErrInvitationExpired):
		writeAPIError(w, http.StatusGone, "invitation_expired", "invitation has expired")
	case errors.Is(err, account.ErrInvitationAlreadyAccepted):
		writeAPIError(w, http.StatusConflict, "invitation_already_accepted", "invitation has already been accepted")
	case errors.Is(err, account.ErrHomeNotFound):
		writeAPIError(w, http.StatusNotFound, "home_not_found", "home not found")
	case errors.Is(err, account.ErrUserNotFound):
		writeAPIError(w, http.StatusNotFound, "user_not_found", "user not found")
	case errors.Is(err, account.ErrCannotRemoveSoleOwner):
		writeAPIError(w, http.StatusConflict, "sole_owner", "cannot remove the sole owner of a home")
	default:
		h.logger.Error().Err(err).Msg("account handler: unexpected error")
		writeAPIError(w, http.StatusInternalServerError, "internal", "internal error")
	}
}

func writeAPIError(w http.ResponseWriter, status int, code, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]any{
		"error": map[string]string{"code": code, "message": message},
	})
}

func invitationView(inv *account.Invitation) map[string]any {
	return map[string]any{
		"uuid":       inv.UUID,
		"home_id":    inv.HomeID,
		"email":      inv.Email,
		"token":      inv.Token,
		"role":       string(inv.Role),
		"expires_at": inv.ExpiresAt,
		"created_at": inv.CreatedAt,
	}
}
