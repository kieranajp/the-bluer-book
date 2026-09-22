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
	accountService accountservice.AccountService
	logger         logger.Logger
}

func NewAccountHandler(accountService accountservice.AccountService, logger logger.Logger) *AccountHandler {
	return &AccountHandler{accountService: accountService, logger: logger}
}

func (h *AccountHandler) writeErrorResponse(w http.ResponseWriter, statusCode int, code, message string) {
	writeAPIError(w, statusCode, code, message)
}

// writeAccountError maps a domain error onto the response it owes the caller.
// Anything it does not recognise becomes a 500, logged against op.
func (h *AccountHandler) writeAccountError(w http.ResponseWriter, op string, err error) {
	switch {
	case errors.Is(err, account.ErrForbidden):
		h.writeErrorResponse(w, http.StatusForbidden, "forbidden", "You may not do that")
	case errors.Is(err, account.ErrHomeNotFound):
		h.writeErrorResponse(w, http.StatusNotFound, "home_not_found", "No such home")
	case errors.Is(err, account.ErrMemberNotFound):
		h.writeErrorResponse(w, http.StatusNotFound, "member_not_found", "No such member")
	case errors.Is(err, account.ErrLastOwner):
		h.writeErrorResponse(w, http.StatusConflict, "last_owner", "Cannot remove a home's last owner")
	case errors.Is(err, account.ErrInvalidRole):
		h.writeErrorResponse(w, http.StatusBadRequest, "invalid_role", "Invalid role")
	case errors.Is(err, account.ErrEmailRequired):
		h.writeErrorResponse(w, http.StatusBadRequest, "email_required", "Invitation email is required")
	case errors.Is(err, account.ErrInvitationNotFound):
		h.writeErrorResponse(w, http.StatusNotFound, "invitation_not_found", "No such invitation")
	case errors.Is(err, account.ErrInvitationExpired):
		h.writeErrorResponse(w, http.StatusGone, "invitation_expired", "Invitation has expired")
	case errors.Is(err, account.ErrInvitationUsed):
		h.writeErrorResponse(w, http.StatusConflict, "invitation_used", "Invitation already accepted")
	default:
		h.logger.Error().Err(err).Str("op", op).Msg("Account operation failed")
		h.writeErrorResponse(w, http.StatusInternalServerError, "internal_error", "Internal error")
	}
}

// callerFromContext handles a missing caller rather than assuming the auth
// middleware always ran first.
func (h *AccountHandler) callerFromContext(w http.ResponseWriter, r *http.Request) (uuid.UUID, bool) {
	userID, ok := auth.UserID(r.Context())
	if !ok {
		h.writeErrorResponse(w, http.StatusUnauthorized, "unauthorized", "No caller in context")
		return uuid.Nil, false
	}
	return userID, true
}

func (h *AccountHandler) homeIDFromPath(w http.ResponseWriter, r *http.Request) (uuid.UUID, bool) {
	homeID, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		h.writeErrorResponse(w, http.StatusBadRequest, "invalid_home_id", "Invalid home id")
		return uuid.Nil, false
	}
	return homeID, true
}

func (h *AccountHandler) targetUserIDFromPath(w http.ResponseWriter, r *http.Request) (uuid.UUID, bool) {
	userID, err := uuid.Parse(r.PathValue("userID"))
	if err != nil {
		h.writeErrorResponse(w, http.StatusBadRequest, "invalid_user_id", "Invalid user id")
		return uuid.Nil, false
	}
	return userID, true
}

// GET /api/me
func (h *AccountHandler) Me(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.callerFromContext(w, r)
	if !ok {
		return
	}
	homeID, ok := auth.HomeID(r.Context())
	if !ok {
		h.writeErrorResponse(w, http.StatusUnauthorized, "unauthorized", "No caller in context")
		return
	}

	homes, err := h.accountService.ListHomes(r.Context(), userID)
	if err != nil {
		h.writeAccountError(w, "list_homes", err)
		return
	}

	me, err := h.accountService.FindUser(r.Context(), userID)
	if err != nil {
		h.writeAccountError(w, "find_user", err)
		return
	}

	homesResp := make([]map[string]any, 0, len(homes))
	for _, m := range homes {
		homesResp = append(homesResp, map[string]any{
			"uuid": m.Home.UUID,
			"name": m.Home.Name,
			"role": m.Role,
		})
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]any{
		"user": map[string]any{
			"uuid":         me.UUID,
			"email":        me.Email,
			"display_name": me.DisplayName,
		},
		"active_home_id": homeID,
		"homes":          homesResp,
	})
}

// POST /api/homes/{id}/invitations returns the plaintext token exactly once;
// only its hash is stored afterwards.
func (h *AccountHandler) CreateInvitation(w http.ResponseWriter, r *http.Request) {
	callerID, ok := h.callerFromContext(w, r)
	if !ok {
		return
	}
	homeID, ok := h.homeIDFromPath(w, r)
	if !ok {
		return
	}

	var body struct {
		Email string       `json:"email"`
		Role  account.Role `json:"role"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		h.writeErrorResponse(w, http.StatusBadRequest, "invalid_request", "Invalid request body")
		return
	}

	inv, token, err := h.accountService.Invite(r.Context(), callerID, homeID, body.Email, body.Role)
	if err != nil {
		h.writeAccountError(w, "invite", err)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]any{
		"invitation": map[string]any{
			"uuid":       inv.UUID,
			"home_id":    inv.HomeID,
			"email":      inv.Email,
			"role":       inv.Role,
			"expires_at": inv.ExpiresAt,
		},
		"token": token,
	})
}

// POST /api/invitations/accept takes the token in the body: a path or query
// version would land a live credential in every access log entry.
func (h *AccountHandler) AcceptInvitation(w http.ResponseWriter, r *http.Request) {
	callerID, ok := h.callerFromContext(w, r)
	if !ok {
		return
	}

	var body struct {
		Token string `json:"token"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		h.writeErrorResponse(w, http.StatusBadRequest, "invalid_request", "Invalid request body")
		return
	}
	if strings.TrimSpace(body.Token) == "" {
		h.writeErrorResponse(w, http.StatusBadRequest, "missing_token", "An invitation token is required")
		return
	}

	home, role, err := h.accountService.AcceptInvitation(r.Context(), callerID, body.Token)
	if err != nil {
		h.writeAccountError(w, "accept_invitation", err)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]any{
		"home": map[string]any{
			"uuid": home.UUID,
			"name": home.Name,
		},
		"role": role,
	})
}

// GET /api/homes/{id}/members
func (h *AccountHandler) ListMembers(w http.ResponseWriter, r *http.Request) {
	callerID, ok := h.callerFromContext(w, r)
	if !ok {
		return
	}
	homeID, ok := h.homeIDFromPath(w, r)
	if !ok {
		return
	}

	members, err := h.accountService.ListMembers(r.Context(), callerID, homeID)
	if err != nil {
		h.writeAccountError(w, "list_members", err)
		return
	}

	resp := make([]map[string]any, 0, len(members))
	for _, m := range members {
		resp = append(resp, map[string]any{
			"user_id":      m.User.UUID,
			"email":        m.User.Email,
			"display_name": m.User.DisplayName,
			"role":         m.Role,
		})
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]any{
		"members": resp,
		"total":   len(resp),
	})
}

// DELETE /api/homes/{id}/members/{userID}
func (h *AccountHandler) RemoveMember(w http.ResponseWriter, r *http.Request) {
	callerID, ok := h.callerFromContext(w, r)
	if !ok {
		return
	}
	homeID, ok := h.homeIDFromPath(w, r)
	if !ok {
		return
	}
	targetID, ok := h.targetUserIDFromPath(w, r)
	if !ok {
		return
	}

	if err := h.accountService.RemoveMember(r.Context(), callerID, homeID, targetID); err != nil {
		h.writeAccountError(w, "remove_member", err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
