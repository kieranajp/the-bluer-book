package auth

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/google/uuid"
	"github.com/rs/zerolog"
)

type noopLogger struct{}

func (n *noopLogger) Info() *zerolog.Event  { l := zerolog.Nop(); return l.Info() }
func (n *noopLogger) Debug() *zerolog.Event { l := zerolog.Nop(); return l.Debug() }
func (n *noopLogger) Warn() *zerolog.Event  { l := zerolog.Nop(); return l.Warn() }
func (n *noopLogger) Error() *zerolog.Event { l := zerolog.Nop(); return l.Error() }

type stubResolver struct {
	seen    Caller
	session Session
	err     error
}

func (s *stubResolver) Resolve(_ context.Context, caller Caller) (Session, error) {
	s.seen = caller
	return s.session, s.err
}

// serve runs one request through the middleware, reporting what the wrapped
// handler saw.
func serve(t *testing.T, resolver UserResolver, headers map[string]string) (*httptest.ResponseRecorder, context.Context, bool) {
	t.Helper()

	var reached bool
	var ctx context.Context
	next := http.HandlerFunc(func(_ http.ResponseWriter, r *http.Request) {
		reached = true
		ctx = r.Context()
	})

	req := httptest.NewRequest(http.MethodGet, "/api/recipes", nil)
	for k, v := range headers {
		req.Header.Set(k, v)
	}

	rec := httptest.NewRecorder()
	Middleware(resolver, &noopLogger{})(next).ServeHTTP(rec, req)
	return rec, ctx, reached
}

func TestRequestWithoutASubjectIsRejected(t *testing.T) {
	for name, headers := range map[string]map[string]string{
		"no header":    {},
		"empty header": {HeaderUser: ""},
		"only spaces":  {HeaderUser: "   "},
	} {
		t.Run(name, func(t *testing.T) {
			rec, _, reached := serve(t, &stubResolver{}, headers)

			if rec.Code != http.StatusUnauthorized {
				t.Errorf("status %d, want 401", rec.Code)
			}
			if reached {
				t.Error("an unauthenticated request reached the handler")
			}

			var body struct {
				Error struct{ Code, Message string }
			}
			if err := json.NewDecoder(rec.Body).Decode(&body); err != nil {
				t.Fatalf("decoding the error body: %v", err)
			}
			if body.Error.Code != "unauthenticated" {
				t.Errorf("error code %q, want unauthenticated", body.Error.Code)
			}
		})
	}
}

func TestResolvedCallerReachesTheHandlerContext(t *testing.T) {
	session := Session{UserID: uuid.New(), HomeID: uuid.New()}
	resolver := &stubResolver{session: session}

	rec, ctx, reached := serve(t, resolver, map[string]string{
		HeaderUser:  "subject-a",
		HeaderEmail: "ada@example.com",
		HeaderName:  "Ada",
	})

	if !reached {
		t.Fatalf("handler not reached, status %d", rec.Code)
	}
	if resolver.seen != (Caller{Subject: "subject-a", Email: "ada@example.com", Name: "Ada"}) {
		t.Errorf("resolver saw %+v", resolver.seen)
	}

	if got, ok := UserID(ctx); !ok || got != session.UserID {
		t.Errorf("user %s in context, want %s", got, session.UserID)
	}
	if got, ok := HomeID(ctx); !ok || got != session.HomeID {
		t.Errorf("home %s in context, want %s", got, session.HomeID)
	}
}

// The email and name headers are optional: a caller arriving with the subject
// alone is still provisioned.
func TestSubjectAloneIsEnough(t *testing.T) {
	resolver := &stubResolver{session: Session{UserID: uuid.New(), HomeID: uuid.New()}}

	rec, _, reached := serve(t, resolver, map[string]string{HeaderUser: "subject-a"})

	if !reached {
		t.Fatalf("handler not reached, status %d", rec.Code)
	}
	if resolver.seen.Email != "" || resolver.seen.Name != "" {
		t.Errorf("resolver saw %+v, want empty email and name", resolver.seen)
	}
}

func TestAFailedResolutionDoesNotReachTheHandler(t *testing.T) {
	resolver := &stubResolver{err: errors.New("connection refused")}

	rec, _, reached := serve(t, resolver, map[string]string{HeaderUser: "subject-a"})

	if rec.Code != http.StatusInternalServerError {
		t.Errorf("status %d, want 500", rec.Code)
	}
	if reached {
		t.Error("a request with no resolved caller reached the handler")
	}
}

func TestHomeIDIsAbsentWithoutTheMiddleware(t *testing.T) {
	if _, ok := HomeID(context.Background()); ok {
		t.Error("a bare context reports a home")
	}
	if _, ok := UserID(context.Background()); ok {
		t.Error("a bare context reports a user")
	}
}

// The edge appends its header rather than replacing what the client sent, so a
// second value is the client's and net/http would hand that one over.
func TestADuplicatedIdentityHeaderIsRejected(t *testing.T) {
	for _, header := range []string{HeaderUser, HeaderEmail, HeaderName} {
		t.Run(header, func(t *testing.T) {
			var reached bool
			next := http.HandlerFunc(func(http.ResponseWriter, *http.Request) { reached = true })

			req := httptest.NewRequest(http.MethodGet, "/api/recipes", nil)
			req.Header.Add(header, "sent-by-the-client")
			req.Header.Add(header, "appended-by-the-edge")
			if header != HeaderUser {
				req.Header.Set(HeaderUser, "real-subject")
			}

			rec := httptest.NewRecorder()
			resolver := &stubResolver{session: Session{UserID: uuid.New(), HomeID: uuid.New()}}
			Middleware(resolver, &noopLogger{})(next).ServeHTTP(rec, req)

			if rec.Code != http.StatusUnauthorized {
				t.Errorf("status %d, want 401", rec.Code)
			}
			if reached {
				t.Error("a request carrying a forged header reached the handler")
			}
			if resolver.seen.Subject != "" {
				t.Errorf("resolver was asked about %q", resolver.seen.Subject)
			}
		})
	}
}

func TestASessionWithNoHomeDoesNotReachTheHandler(t *testing.T) {
	for name, session := range map[string]Session{
		"no home": {UserID: uuid.New()},
		"no user": {HomeID: uuid.New()},
		"neither": {},
	} {
		t.Run(name, func(t *testing.T) {
			rec, _, reached := serve(t, &stubResolver{session: session}, map[string]string{HeaderUser: "subject-a"})

			if rec.Code != http.StatusInternalServerError {
				t.Errorf("status %d, want 500", rec.Code)
			}
			if reached {
				t.Error("a request with no home reached the handler")
			}
		})
	}
}

// X-Home is the one header a client sets for itself, so every test below asks
// what happens when it is wrong rather than when it is right.

func TestNoHomeHeaderAsksForNoParticularHome(t *testing.T) {
	resolver := &stubResolver{session: Session{UserID: uuid.New(), HomeID: uuid.New()}}

	_, _, reached := serve(t, resolver, map[string]string{HeaderUser: "subject-a"})

	if !reached {
		t.Fatal("handler not reached")
	}
	if resolver.seen.Home != uuid.Nil {
		t.Errorf("resolver was asked for home %s, want none", resolver.seen.Home)
	}
}

// The resolved home differs from the requested one so the context assertion
// means something: given one uuid for both, stamping either would pass.
func TestTheRequestedHomeReachesTheResolver(t *testing.T) {
	requested, resolved := uuid.New(), uuid.New()
	resolver := &stubResolver{session: Session{UserID: uuid.New(), HomeID: resolved}}

	_, ctx, reached := serve(t, resolver, map[string]string{
		HeaderUser: "subject-a",
		HeaderHome: requested.String(),
	})

	if !reached {
		t.Fatal("handler not reached")
	}
	if resolver.seen.Home != requested {
		t.Errorf("resolver was asked for home %s, want %s", resolver.seen.Home, requested)
	}
	if got, _ := HomeID(ctx); got != resolved {
		t.Errorf("context carries home %s, want the resolver's %s", got, resolved)
	}
}

// The resolver decides membership; the middleware refuses with a code of its
// own, so a client can drop the home it is holding rather than read the answer
// as an expired session.
func TestNamingAHomeYouAreNotInIsRefused(t *testing.T) {
	home := uuid.New()
	resolver := &stubResolver{
		session: Session{UserID: uuid.New(), HomeID: uuid.New()},
		err:     ErrHomeForbidden,
	}

	rec, _, reached := serve(t, resolver, map[string]string{
		HeaderUser: "subject-b",
		HeaderHome: home.String(),
	})

	if rec.Code != http.StatusForbidden {
		t.Errorf("status %d, want 403", rec.Code)
	}
	if reached {
		t.Error("a request naming somebody else's home reached the handler")
	}

	var body struct {
		Error struct{ Code, Message string }
	}
	if err := json.NewDecoder(rec.Body).Decode(&body); err != nil {
		t.Fatalf("decoding the error body: %v", err)
	}
	if body.Error.Code != "home_forbidden" {
		t.Errorf("error code %q, want home_forbidden", body.Error.Code)
	}
	if strings.Contains(body.Error.Message, home.String()) {
		t.Errorf("the refusal repeats the home id back: %q", body.Error.Message)
	}
}

// A home id that does not parse is a client fault, and the resolver is never
// asked: there is no value to ask about, and guessing one would be worse.
func TestAnUnusableHomeHeaderIsRefusedBeforeResolution(t *testing.T) {
	for name, value := range map[string]string{
		"not a uuid":   "home-a",
		"truncated":    "00000000-0000-0000-0000",
		"sql fragment": "' OR '1'='1",
		"nil uuid":     uuid.Nil.String(),
	} {
		t.Run(name, func(t *testing.T) {
			resolver := &stubResolver{session: Session{UserID: uuid.New(), HomeID: uuid.New()}}

			rec, _, reached := serve(t, resolver, map[string]string{
				HeaderUser: "subject-a",
				HeaderHome: value,
			})

			if rec.Code != http.StatusBadRequest {
				t.Errorf("status %d, want 400", rec.Code)
			}
			if reached {
				t.Error("a request with an unusable home header reached the handler")
			}
			if resolver.seen.Subject != "" {
				t.Error("the resolver was asked about a request that never had a home")
			}
		})
	}
}

// Two X-Home values are two answers to one question. net/http would hand over
// the first, which is no basis for deciding whose data a request reads.
func TestADuplicatedHomeHeaderIsRefused(t *testing.T) {
	var reached bool
	next := http.HandlerFunc(func(http.ResponseWriter, *http.Request) { reached = true })

	req := httptest.NewRequest(http.MethodGet, "/api/recipes", nil)
	req.Header.Set(HeaderUser, "subject-a")
	req.Header.Add(HeaderHome, uuid.New().String())
	req.Header.Add(HeaderHome, uuid.New().String())

	rec := httptest.NewRecorder()
	resolver := &stubResolver{session: Session{UserID: uuid.New(), HomeID: uuid.New()}}
	Middleware(resolver, &noopLogger{})(next).ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("status %d, want 400", rec.Code)
	}
	if reached {
		t.Error("a request carrying two home headers reached the handler")
	}
	if resolver.seen.Subject != "" {
		t.Error("the resolver was asked to pick between two homes")
	}
}
