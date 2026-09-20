package api

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/google/uuid"

	"github.com/kieranajp/the-bluer-book/internal/infrastructure/auth"
)

type stubResolver struct {
	session auth.Session
}

func (s *stubResolver) Resolve(context.Context, auth.Caller) (auth.Session, error) {
	return s.session, nil
}

// testRouter builds the real router over stub services. The chat handler is nil:
// no case here reaches POST /api/chat, and registering it takes no dereference.
func testRouter() http.Handler {
	resolver := &stubResolver{session: auth.Session{UserID: uuid.New(), HomeID: uuid.New()}}
	return NewRouter(&stubRecipeService{}, &stubPantryService{}, nil, nil, nil, resolver, &noopLogger{})
}

func TestRoutesOutsideTheAPINeedNoCaller(t *testing.T) {
	router := testRouter()

	for _, path := range []string{"/health", "/metrics"} {
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, path, nil))

		if rec.Code != http.StatusOK {
			t.Errorf("%s returned %d without a caller, want 200", path, rec.Code)
		}
	}
}

func TestEveryAPIRouteNeedsACaller(t *testing.T) {
	router := testRouter()

	for _, path := range []string{"/api/recipes", "/api/units", "/api/pantry", "/api/shopping-list", "/api/nothing-here"} {
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, path, nil))

		if rec.Code != http.StatusUnauthorized {
			t.Errorf("%s returned %d without a caller, want 401", path, rec.Code)
		}
	}
}

func TestPathValuesSurviveTheNestedMux(t *testing.T) {
	id := uuid.New()
	rec := httptest.NewRecorder()

	req := httptest.NewRequest(http.MethodGet, "/api/recipes/"+id.String(), nil)
	req.Header.Set(auth.HeaderUser, "subject-a")
	testRouter().ServeHTTP(rec, req)

	// The stub service returns no recipe, so the handler reports it missing —
	// which it can only do having parsed the id out of the path.
	if rec.Code != http.StatusNotFound {
		t.Errorf("status %d, want 404 from a handler that read the id", rec.Code)
	}
}

func TestAnAuthenticatedCallerReachesTheHandlers(t *testing.T) {
	router := testRouter()

	req := httptest.NewRequest(http.MethodGet, "/api/units", nil)
	req.Header.Set(auth.HeaderUser, "subject-a")

	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("status %d, want 200", rec.Code)
	}
}
