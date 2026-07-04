package auth

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/google/uuid"

	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/storage/db"
)

type stubResolver struct {
	user db.User
	home db.Home
	err  error

	lastSubject       string
	lastRequestedHome *uuid.UUID
}

func (s *stubResolver) Resolve(_ context.Context, subject string, requested *uuid.UUID) (db.User, db.Home, error) {
	s.lastSubject = subject
	s.lastRequestedHome = requested
	return s.user, s.home, s.err
}

func TestMiddleware_RejectsMissingSubject(t *testing.T) {
	resolver := &stubResolver{}
	h := Middleware(resolver, logger.New(logger.LogLevelError))(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
		t.Fatal("downstream should not run for unauthenticated request")
	}))

	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/api/recipes", nil))
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", rec.Code)
	}
}

func TestMiddleware_RejectsUnknownSubject(t *testing.T) {
	resolver := &stubResolver{err: ErrUnknownSubject}
	h := Middleware(resolver, logger.New(logger.LogLevelError))(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
		t.Fatal("downstream should not run for unknown subject")
	}))

	req := httptest.NewRequest(http.MethodGet, "/api/recipes", nil)
	req.Header.Set(HeaderUser, "kratos-id-unknown")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401 for unknown subject, got %d", rec.Code)
	}
}

func TestMiddleware_StashesIdentityInContext(t *testing.T) {
	wantUser := db.User{Uuid: uuid.New()}
	wantHome := db.Home{Uuid: uuid.New()}
	resolver := &stubResolver{user: wantUser, home: wantHome}

	var gotUser, gotHome uuid.UUID
	var hadUser, hadHome bool
	h := Middleware(resolver, logger.New(logger.LogLevelError))(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotUser, hadUser = UserID(r.Context())
		gotHome, hadHome = HomeID(r.Context())
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodGet, "/api/recipes", nil)
	req.Header.Set(HeaderUser, "kratos-id-123")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
	if !hadUser || gotUser != wantUser.Uuid {
		t.Fatalf("user id missing or wrong: got=%v had=%v want=%v", gotUser, hadUser, wantUser.Uuid)
	}
	if !hadHome || gotHome != wantHome.Uuid {
		t.Fatalf("home id missing or wrong: got=%v had=%v want=%v", gotHome, hadHome, wantHome.Uuid)
	}
	if resolver.lastSubject != "kratos-id-123" {
		t.Fatalf("resolver got subject %q, want kratos-id-123", resolver.lastSubject)
	}
	if resolver.lastRequestedHome != nil {
		t.Fatalf("expected no requested home when X-Home absent, got %v", *resolver.lastRequestedHome)
	}
}

func TestMiddleware_HonoursRequestedHome(t *testing.T) {
	wantUser := db.User{Uuid: uuid.New()}
	wantHome := db.Home{Uuid: uuid.New()}
	resolver := &stubResolver{user: wantUser, home: wantHome}

	h := Middleware(resolver, logger.New(logger.LogLevelError))(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	requested := uuid.New()
	req := httptest.NewRequest(http.MethodGet, "/api/recipes", nil)
	req.Header.Set(HeaderUser, "kratos-id-123")
	req.Header.Set(HeaderHome, requested.String())
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
	if resolver.lastRequestedHome == nil || *resolver.lastRequestedHome != requested {
		t.Fatalf("requested home not forwarded: got=%v want=%v", resolver.lastRequestedHome, requested)
	}
}

func TestMiddleware_RejectsMalformedHomeHeader(t *testing.T) {
	resolver := &stubResolver{}
	h := Middleware(resolver, logger.New(logger.LogLevelError))(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
		t.Fatal("downstream should not run for malformed X-Home")
	}))

	req := httptest.NewRequest(http.MethodGet, "/api/recipes", nil)
	req.Header.Set(HeaderUser, "kratos-id-123")
	req.Header.Set(HeaderHome, "not-a-uuid")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for malformed X-Home, got %d", rec.Code)
	}
}
