package chat

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/google/uuid"

	"github.com/kieranajp/the-bluer-book/internal/infrastructure/auth"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/metrics"
)

// gated builds only the part of the handler the home check reads, because the
// rest needs a Gemini key and a live MCP server, and a refusal reaches neither.
func gated(mcpHome uuid.UUID) *Handler {
	return &Handler{
		logger:    logger.New(logger.LogLevelError),
		probe:     metrics.NoopChatProbe{},
		mcpHomeID: mcpHome,
	}
}

func post(h *Handler, home uuid.UUID, hasHome bool, body string) *httptest.ResponseRecorder {
	r := httptest.NewRequest(http.MethodPost, "/api/chat", strings.NewReader(body))
	if hasHome {
		r = r.WithContext(auth.WithIdentity(r.Context(), uuid.New(), home))
	}
	rec := httptest.NewRecorder()
	h.HandleChat(rec, r)
	return rec
}

// The MCP server the agent calls is pinned to one home, so a member of any
// other would read and write that home's book through it.
func TestChatRefusesAHomeTheAssistantDoesNotActOn(t *testing.T) {
	mcpHome := uuid.New()
	rec := post(gated(mcpHome), uuid.New(), true, `{"message":"what is in my book?"}`)

	if rec.Code != http.StatusForbidden {
		t.Errorf("status %d, want 403", rec.Code)
	}

	var body struct {
		Error struct{ Code, Message string }
	}
	if err := json.NewDecoder(rec.Body).Decode(&body); err != nil {
		t.Fatalf("decoding the error body: %v", err)
	}
	if body.Error.Code != "chat_unavailable_for_home" {
		t.Errorf("error code %q, want chat_unavailable_for_home", body.Error.Code)
	}
	if body.Error.Message == "" {
		t.Error("the refusal carries no message for a client to show")
	}
}

// Fails closed: no home means the identity middleware is not in the chain.
func TestChatRefusesARequestCarryingNoHome(t *testing.T) {
	rec := post(gated(uuid.New()), uuid.Nil, false, `{"message":"hello"}`)

	if rec.Code != http.StatusForbidden {
		t.Errorf("status %d, want 403", rec.Code)
	}
}

// The matching home gets past the gate, which the 400 on a body the handler
// cannot read proves without needing a model behind it.
func TestChatAdmitsTheHomeTheAssistantActsOn(t *testing.T) {
	mcpHome := uuid.New()
	rec := post(gated(mcpHome), mcpHome, true, `not json`)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("status %d, want 400 — the gate refused the home it acts on", rec.Code)
	}
}
