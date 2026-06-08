package auth

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/google/uuid"

	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
)

// recordingRT captures the request it's handed so the test can assert
// what headers ended up on the wire.
type recordingRT struct {
	got *http.Request
}

func (rt *recordingRT) RoundTrip(req *http.Request) (*http.Response, error) {
	rt.got = req
	return &http.Response{StatusCode: 204, Body: http.NoBody, Header: make(http.Header)}, nil
}

func TestHomeHeaderRoundTripper_AddsHeaderWhenHomePresent(t *testing.T) {
	rec := &recordingRT{}
	rt := &HomeHeaderRoundTripper{Base: rec}

	home := uuid.New()
	req, _ := http.NewRequestWithContext(WithHome(context.Background(), home), http.MethodPost, "http://x/mcp", nil)

	if _, err := rt.RoundTrip(req); err != nil {
		t.Fatalf("RoundTrip: %v", err)
	}
	if got := rec.got.Header.Get(HeaderHome); got != home.String() {
		t.Fatalf("X-Home = %q, want %q", got, home.String())
	}
	// Original request must not have been mutated (RoundTripper contract).
	if req.Header.Get(HeaderHome) != "" {
		t.Fatalf("RoundTripper mutated the caller's request")
	}
}

func TestHomeHeaderRoundTripper_OmitsHeaderWhenContextEmpty(t *testing.T) {
	rec := &recordingRT{}
	rt := &HomeHeaderRoundTripper{Base: rec}

	req, _ := http.NewRequest(http.MethodPost, "http://x/mcp", nil)
	if _, err := rt.RoundTrip(req); err != nil {
		t.Fatalf("RoundTrip: %v", err)
	}
	if got := rec.got.Header.Get(HeaderHome); got != "" {
		t.Fatalf("expected no X-Home header, got %q", got)
	}
}

func TestInjectHomeFromHeader_PopulatesContext(t *testing.T) {
	fn := InjectHomeFromHeader(logger.New(logger.LogLevelError))

	home := uuid.New()
	req := httptest.NewRequest(http.MethodPost, "/mcp", nil)
	req.Header.Set(HeaderHome, home.String())

	got := fn(context.Background(), req)
	id, ok := HomeID(got)
	if !ok {
		t.Fatalf("HomeID not present after InjectHomeFromHeader")
	}
	if id != home {
		t.Fatalf("HomeID = %s, want %s", id, home)
	}
}

func TestInjectHomeFromHeader_NoHeaderLeavesContextUnchanged(t *testing.T) {
	fn := InjectHomeFromHeader(logger.New(logger.LogLevelError))

	req := httptest.NewRequest(http.MethodPost, "/mcp", nil)
	got := fn(context.Background(), req)
	if _, ok := HomeID(got); ok {
		t.Fatalf("HomeID should not be set when no X-Home header is present")
	}
}

func TestInjectHomeFromHeader_MalformedHeaderIsIgnored(t *testing.T) {
	fn := InjectHomeFromHeader(logger.New(logger.LogLevelError))

	req := httptest.NewRequest(http.MethodPost, "/mcp", nil)
	req.Header.Set(HeaderHome, "not-a-uuid")
	got := fn(context.Background(), req)
	if _, ok := HomeID(got); ok {
		t.Fatalf("HomeID should not be set for a malformed X-Home header")
	}
}
