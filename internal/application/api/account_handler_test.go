package api

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/google/uuid"

	"github.com/kieranajp/the-bluer-book/internal/domain/account"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/auth"
)

// --- Stub ---

type stubAccountService struct {
	user    account.User
	userErr error

	homes    []account.Membership
	homesErr error

	members    []account.Member
	membersErr error

	inviteInv   account.Invitation
	inviteToken string
	inviteErr   error

	acceptHome account.Home
	acceptRole account.Role
	acceptErr  error

	removeErr error

	// What each method was actually called with, so tests can assert the
	// handler passed the caller from context rather than from the path or
	// body.
	findUserID         uuid.UUID
	listHomesUserID    uuid.UUID
	inviteActorID      uuid.UUID
	inviteHomeID       uuid.UUID
	inviteEmail        string
	inviteRole         account.Role
	acceptUserID       uuid.UUID
	acceptToken        string
	listMembersActorID uuid.UUID
	listMembersHomeID  uuid.UUID
	removeActorID      uuid.UUID
	removeHomeID       uuid.UUID
	removeTargetID     uuid.UUID
}

func (s *stubAccountService) ProvisionFromSubject(context.Context, account.Identity) (account.User, error) {
	return account.User{}, nil
}

func (s *stubAccountService) ResolveActiveHome(context.Context, account.User, uuid.UUID) (account.Home, error) {
	return account.Home{}, nil
}

func (s *stubAccountService) ListHomes(_ context.Context, userID uuid.UUID) ([]account.Membership, error) {
	s.listHomesUserID = userID
	return s.homes, s.homesErr
}

func (s *stubAccountService) Invite(_ context.Context, actorID, homeID uuid.UUID, email string, role account.Role) (account.Invitation, string, error) {
	s.inviteActorID, s.inviteHomeID, s.inviteEmail, s.inviteRole = actorID, homeID, email, role
	return s.inviteInv, s.inviteToken, s.inviteErr
}

func (s *stubAccountService) AcceptInvitation(_ context.Context, userID uuid.UUID, token string) (account.Home, account.Role, error) {
	s.acceptUserID, s.acceptToken = userID, token
	return s.acceptHome, s.acceptRole, s.acceptErr
}

func (s *stubAccountService) FindUser(_ context.Context, userID uuid.UUID) (account.User, error) {
	s.findUserID = userID
	return s.user, s.userErr
}

func (s *stubAccountService) ListMembers(_ context.Context, actorID, homeID uuid.UUID) ([]account.Member, error) {
	s.listMembersActorID, s.listMembersHomeID = actorID, homeID
	return s.members, s.membersErr
}

func (s *stubAccountService) RemoveMember(_ context.Context, actorID, homeID, targetID uuid.UUID) error {
	s.removeActorID, s.removeHomeID, s.removeTargetID = actorID, homeID, targetID
	return s.removeErr
}

// --- Helpers ---

// withCaller stamps a request context the way the auth middleware would,
// short of running the middleware itself.
func withCaller(r *http.Request, userID, homeID uuid.UUID) *http.Request {
	return r.WithContext(auth.WithIdentity(r.Context(), userID, homeID))
}

// --- Me ---

func TestMe_Success(t *testing.T) {
	userID, homeID := uuid.New(), uuid.New()
	svc := &stubAccountService{
		homes: []account.Membership{
			{Home: account.Home{UUID: homeID, Name: "The Book"}, Role: account.RoleOwner},
		},
		user: account.User{UUID: userID, Email: "ada@example.com", DisplayName: "Ada"},
	}
	h := NewAccountHandler(svc, &noopLogger{})

	req := withCaller(httptest.NewRequest(http.MethodGet, "/api/me", nil), userID, homeID)
	rec := httptest.NewRecorder()
	h.Me(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}

	var body struct {
		User struct {
			UUID        string `json:"uuid"`
			Email       string `json:"email"`
			DisplayName string `json:"display_name"`
		} `json:"user"`
		ActiveHomeID string `json:"active_home_id"`
		Homes        []struct {
			UUID string `json:"uuid"`
			Name string `json:"name"`
			Role string `json:"role"`
		} `json:"homes"`
	}
	if err := json.NewDecoder(rec.Body).Decode(&body); err != nil {
		t.Fatalf("decoding response: %v", err)
	}
	if body.User.UUID != userID.String() || body.User.Email != "ada@example.com" || body.User.DisplayName != "Ada" {
		t.Errorf("user = %+v", body.User)
	}
	if body.ActiveHomeID != homeID.String() {
		t.Errorf("active_home_id = %q, want %q", body.ActiveHomeID, homeID.String())
	}
	if len(body.Homes) != 1 || body.Homes[0].Role != "owner" {
		t.Errorf("homes = %+v", body.Homes)
	}
	if svc.listHomesUserID != userID || svc.findUserID != userID {
		t.Errorf("service asked about ListHomes=%s FindUser=%s, want caller %s", svc.listHomesUserID, svc.findUserID, userID)
	}
}

func TestMe_NoCallerInContext(t *testing.T) {
	h := NewAccountHandler(&stubAccountService{}, &noopLogger{})

	req := httptest.NewRequest(http.MethodGet, "/api/me", nil)
	rec := httptest.NewRecorder()
	h.Me(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", rec.Code)
	}
}

// --- CreateInvitation ---

func TestCreateInvitation_Success(t *testing.T) {
	callerID, homeID, invID := uuid.New(), uuid.New(), uuid.New()
	svc := &stubAccountService{
		inviteInv:   account.Invitation{UUID: invID, HomeID: homeID, Email: "bob@example.com", Role: account.RoleMember},
		inviteToken: "plaintext-token",
	}
	h := NewAccountHandler(svc, &noopLogger{})

	req := httptest.NewRequest(http.MethodPost, "/api/homes/"+homeID.String()+"/invitations", strings.NewReader(`{"email": "bob@example.com", "role": "member"}`))
	req.SetPathValue("id", homeID.String())
	req = withCaller(req, callerID, homeID)

	rec := httptest.NewRecorder()
	h.CreateInvitation(rec, req)

	if rec.Code != http.StatusCreated {
		t.Fatalf("expected 201, got %d: %s", rec.Code, rec.Body.String())
	}

	var body struct {
		Invitation struct {
			UUID   string `json:"uuid"`
			HomeID string `json:"home_id"`
			Email  string `json:"email"`
			Role   string `json:"role"`
		} `json:"invitation"`
		Token string `json:"token"`
	}
	if err := json.NewDecoder(rec.Body).Decode(&body); err != nil {
		t.Fatalf("decoding response: %v", err)
	}
	if body.Token != "plaintext-token" {
		t.Errorf("token = %q, want the plaintext token", body.Token)
	}
	if body.Invitation.UUID != invID.String() || body.Invitation.Email != "bob@example.com" || body.Invitation.Role != "member" {
		t.Errorf("invitation = %+v", body.Invitation)
	}
	if svc.inviteActorID != callerID {
		t.Errorf("Invite called with actor %s, want caller %s", svc.inviteActorID, callerID)
	}
	if svc.inviteHomeID != homeID {
		t.Errorf("Invite called with home %s, want %s", svc.inviteHomeID, homeID)
	}
}

// A non-owner invite is refused before anything resembling a token exists.
func TestCreateInvitation_NonOwnerIsForbidden(t *testing.T) {
	callerID, homeID := uuid.New(), uuid.New()
	svc := &stubAccountService{inviteErr: account.ErrForbidden}
	h := NewAccountHandler(svc, &noopLogger{})

	req := httptest.NewRequest(http.MethodPost, "/api/homes/"+homeID.String()+"/invitations", strings.NewReader(`{"email": "bob@example.com"}`))
	req.SetPathValue("id", homeID.String())
	req = withCaller(req, callerID, homeID)

	rec := httptest.NewRecorder()
	h.CreateInvitation(rec, req)

	if rec.Code != http.StatusForbidden {
		t.Fatalf("expected 403, got %d", rec.Code)
	}
	if strings.Contains(rec.Body.String(), "token") {
		t.Errorf("a forbidden response mentions a token: %s", rec.Body.String())
	}
}

func TestCreateInvitation_MalformedHomeIDNeverReachesTheService(t *testing.T) {
	svc := &stubAccountService{}
	h := NewAccountHandler(svc, &noopLogger{})

	req := httptest.NewRequest(http.MethodPost, "/api/homes/not-a-uuid/invitations", strings.NewReader(`{"email":"bob@example.com"}`))
	req.SetPathValue("id", "not-a-uuid")
	req = withCaller(req, uuid.New(), uuid.New())

	rec := httptest.NewRecorder()
	h.CreateInvitation(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}
	if svc.inviteActorID != uuid.Nil {
		t.Error("the service was called with a malformed home id")
	}
}

// --- AcceptInvitation ---

func TestAcceptInvitation_Success(t *testing.T) {
	callerID, homeID := uuid.New(), uuid.New()
	svc := &stubAccountService{
		acceptHome: account.Home{UUID: homeID, Name: "The Book"},
		acceptRole: account.RoleMember,
	}
	h := NewAccountHandler(svc, &noopLogger{})

	req := httptest.NewRequest(http.MethodPost, "/api/invitations/accept",
		strings.NewReader(`{"token": "tok123"}`))
	req = withCaller(req, callerID, homeID)

	rec := httptest.NewRecorder()
	h.AcceptInvitation(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}

	var body struct {
		Home struct {
			UUID string `json:"uuid"`
			Name string `json:"name"`
		} `json:"home"`
		Role string `json:"role"`
	}
	if err := json.NewDecoder(rec.Body).Decode(&body); err != nil {
		t.Fatalf("decoding response: %v", err)
	}
	if body.Home.UUID != homeID.String() || body.Role != "member" {
		t.Errorf("body = %+v", body)
	}
	if svc.acceptUserID != callerID {
		t.Errorf("AcceptInvitation called with %s, want caller %s", svc.acceptUserID, callerID)
	}
	if svc.acceptToken != "tok123" {
		t.Errorf("AcceptInvitation called with token %q, want %q", svc.acceptToken, "tok123")
	}
}

// --- ListMembers ---

// The token is a bearer credential and the access log records every path, so
// the request body is the only place it may travel.
func TestAcceptInvitationTakesTheTokenFromTheBody(t *testing.T) {
	callerID, homeID := uuid.New(), uuid.New()
	svc := &stubAccountService{acceptHome: account.Home{UUID: homeID}, acceptRole: account.RoleMember}
	h := NewAccountHandler(svc, &noopLogger{})

	req := httptest.NewRequest(http.MethodPost, "/api/invitations/accept",
		strings.NewReader(`{"token": "tok123"}`))
	// A path value the handler must ignore: were it read instead, the token
	// would be in the URL and therefore in the log.
	req.SetPathValue("token", "from-the-path")
	req = withCaller(req, callerID, homeID)

	h.AcceptInvitation(httptest.NewRecorder(), req)

	if svc.acceptToken != "tok123" {
		t.Errorf("redeemed %q, want the body's token", svc.acceptToken)
	}
}

func TestAcceptInvitationNeedsAToken(t *testing.T) {
	for name, body := range map[string]string{
		"no token":    `{}`,
		"empty token": `{"token": ""}`,
		"whitespace":  `{"token": "   "}`,
		"not json":    `nonsense`,
	} {
		t.Run(name, func(t *testing.T) {
			svc := &stubAccountService{}
			h := NewAccountHandler(svc, &noopLogger{})

			req := withCaller(httptest.NewRequest(http.MethodPost, "/api/invitations/accept",
				strings.NewReader(body)), uuid.New(), uuid.New())
			rec := httptest.NewRecorder()
			h.AcceptInvitation(rec, req)

			if rec.Code != http.StatusBadRequest {
				t.Errorf("status %d, want 400", rec.Code)
			}
			if svc.acceptToken != "" {
				t.Errorf("the service was asked to redeem %q", svc.acceptToken)
			}
		})
	}
}

func TestListMembers_Success(t *testing.T) {
	callerID, homeID := uuid.New(), uuid.New()
	svc := &stubAccountService{
		members: []account.Member{
			{User: account.User{UUID: uuid.New(), Email: "a@example.com", DisplayName: "A"}, Role: account.RoleOwner},
			{User: account.User{UUID: uuid.New(), Email: "b@example.com", DisplayName: "B"}, Role: account.RoleMember},
		},
	}
	h := NewAccountHandler(svc, &noopLogger{})

	req := httptest.NewRequest(http.MethodGet, "/api/homes/"+homeID.String()+"/members", nil)
	req.SetPathValue("id", homeID.String())
	req = withCaller(req, callerID, homeID)

	rec := httptest.NewRecorder()
	h.ListMembers(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}

	var body struct {
		Members []struct {
			UserID      string `json:"user_id"`
			Email       string `json:"email"`
			DisplayName string `json:"display_name"`
			Role        string `json:"role"`
		} `json:"members"`
		Total int `json:"total"`
	}
	if err := json.NewDecoder(rec.Body).Decode(&body); err != nil {
		t.Fatalf("decoding response: %v", err)
	}
	if body.Total != 2 || len(body.Members) != 2 {
		t.Fatalf("expected 2 members, got total=%d len=%d", body.Total, len(body.Members))
	}
	if svc.listMembersActorID != callerID || svc.listMembersHomeID != homeID {
		t.Errorf("ListMembers called with actor=%s home=%s", svc.listMembersActorID, svc.listMembersHomeID)
	}
}

func TestListMembers_MalformedHomeIDNeverReachesTheService(t *testing.T) {
	svc := &stubAccountService{}
	h := NewAccountHandler(svc, &noopLogger{})

	req := httptest.NewRequest(http.MethodGet, "/api/homes/not-a-uuid/members", nil)
	req.SetPathValue("id", "not-a-uuid")
	req = withCaller(req, uuid.New(), uuid.New())

	rec := httptest.NewRecorder()
	h.ListMembers(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}
	if svc.listMembersActorID != uuid.Nil {
		t.Error("the service was called with a malformed home id")
	}
}

// --- RemoveMember ---

func TestRemoveMember_Success(t *testing.T) {
	callerID, homeID, targetID := uuid.New(), uuid.New(), uuid.New()
	svc := &stubAccountService{}
	h := NewAccountHandler(svc, &noopLogger{})

	req := httptest.NewRequest(http.MethodDelete, "/api/homes/"+homeID.String()+"/members/"+targetID.String(), nil)
	req.SetPathValue("id", homeID.String())
	req.SetPathValue("userID", targetID.String())
	req = withCaller(req, callerID, homeID)

	rec := httptest.NewRecorder()
	h.RemoveMember(rec, req)

	if rec.Code != http.StatusNoContent {
		t.Fatalf("expected 204, got %d", rec.Code)
	}
	if svc.removeActorID != callerID || svc.removeHomeID != homeID || svc.removeTargetID != targetID {
		t.Errorf("RemoveMember called with actor=%s home=%s target=%s, want %s/%s/%s",
			svc.removeActorID, svc.removeHomeID, svc.removeTargetID, callerID, homeID, targetID)
	}
}

// Removing the last owner is refused by the service; the handler must map
// that refusal to 409 rather than treat it as success or as a generic error.
func TestRemoveMember_LastOwner(t *testing.T) {
	svc := &stubAccountService{removeErr: account.ErrLastOwner}
	h := NewAccountHandler(svc, &noopLogger{})

	homeID, targetID := uuid.New(), uuid.New()
	req := httptest.NewRequest(http.MethodDelete, "/api/homes/"+homeID.String()+"/members/"+targetID.String(), nil)
	req.SetPathValue("id", homeID.String())
	req.SetPathValue("userID", targetID.String())
	req = withCaller(req, uuid.New(), homeID)

	rec := httptest.NewRecorder()
	h.RemoveMember(rec, req)

	if rec.Code != http.StatusConflict {
		t.Fatalf("expected 409, got %d", rec.Code)
	}
}

func TestRemoveMember_MalformedTargetIDNeverReachesTheService(t *testing.T) {
	svc := &stubAccountService{}
	h := NewAccountHandler(svc, &noopLogger{})

	homeID := uuid.New()
	req := httptest.NewRequest(http.MethodDelete, "/api/homes/"+homeID.String()+"/members/not-a-uuid", nil)
	req.SetPathValue("id", homeID.String())
	req.SetPathValue("userID", "not-a-uuid")
	req = withCaller(req, uuid.New(), homeID)

	rec := httptest.NewRecorder()
	h.RemoveMember(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}
	if svc.removeActorID != uuid.Nil {
		t.Error("the service was called with a malformed target id")
	}
}

// --- Error mapping ---
//
// One table, one row per mapped error, so changing a status or a code fails
// here rather than reaching a client. It cannot notice a sentinel that was
// never added to it. ListMembers is the vehicle: it passes any service error
// straight through with no branching of its own.

func TestAccountErrorMapping(t *testing.T) {
	cases := []struct {
		err    error
		status int
		code   string
	}{
		{account.ErrForbidden, http.StatusForbidden, "forbidden"},
		{account.ErrHomeNotFound, http.StatusNotFound, "home_not_found"},
		{account.ErrMemberNotFound, http.StatusNotFound, "member_not_found"},
		{account.ErrLastOwner, http.StatusConflict, "last_owner"},
		{account.ErrInvalidRole, http.StatusBadRequest, "invalid_role"},
		{account.ErrEmailRequired, http.StatusBadRequest, "email_required"},
		{account.ErrInvitationNotFound, http.StatusNotFound, "invitation_not_found"},
		{account.ErrInvitationExpired, http.StatusGone, "invitation_expired"},
		{account.ErrInvitationUsed, http.StatusConflict, "invitation_used"},
		{errors.New("boom"), http.StatusInternalServerError, "internal_error"},
	}

	for _, tc := range cases {
		t.Run(tc.code, func(t *testing.T) {
			homeID := uuid.New()
			svc := &stubAccountService{membersErr: tc.err}
			h := NewAccountHandler(svc, &noopLogger{})

			req := httptest.NewRequest(http.MethodGet, "/api/homes/"+homeID.String()+"/members", nil)
			req.SetPathValue("id", homeID.String())
			req = withCaller(req, uuid.New(), homeID)

			rec := httptest.NewRecorder()
			h.ListMembers(rec, req)

			if rec.Code != tc.status {
				t.Errorf("status = %d, want %d", rec.Code, tc.status)
			}

			var body struct {
				Error struct {
					Code string `json:"code"`
				} `json:"error"`
			}
			if err := json.NewDecoder(rec.Body).Decode(&body); err != nil {
				t.Fatalf("decoding error body: %v", err)
			}
			if body.Error.Code != tc.code {
				t.Errorf("code = %q, want %q", body.Error.Code, tc.code)
			}
		})
	}
}
