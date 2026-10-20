package api

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/kieranajp/the-bluer-book/internal/domain/account"
	"github.com/kieranajp/the-bluer-book/internal/domain/recipe"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/auth"
)

const linkToken = "link-token-for-home-a"

// homeRecordingRecipeService remembers the home each read ran in.
type homeRecordingRecipeService struct {
	stubRecipeService
	homes []uuid.UUID
}

func (s *homeRecordingRecipeService) record(ctx context.Context) {
	home, _ := auth.HomeID(ctx)
	s.homes = append(s.homes, home)
}

func (s *homeRecordingRecipeService) RecipeIndex(ctx context.Context) ([]recipe.IndexEntry, error) {
	s.record(ctx)
	return s.stubRecipeService.RecipeIndex(ctx)
}

func (s *homeRecordingRecipeService) GetRecipe(ctx context.Context, id uuid.UUID) (*recipe.Recipe, error) {
	s.record(ctx)
	return s.stubRecipeService.GetRecipe(ctx, id)
}

func (s *homeRecordingRecipeService) ListMealPlanRecipes(ctx context.Context) ([]*recipe.Recipe, error) {
	s.record(ctx)
	return s.stubRecipeService.ListMealPlanRecipes(ctx)
}

func linkRouter(recipes *homeRecordingRecipeService, link account.Link) http.Handler {
	accounts := &stubAccountService{links: map[string]account.Link{linkToken: link}}
	resolver := &stubResolver{session: auth.Session{UserID: uuid.New(), HomeID: uuid.New()}}
	return NewRouter(recipes, &stubPantryService{}, accounts, nil, nil, nil, resolver, &noopLogger{})
}

func linkRequest(method, path, token string) *http.Request {
	req := httptest.NewRequest(method, path, nil)
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	return req
}

func errorCode(t *testing.T, rec *httptest.ResponseRecorder) string {
	t.Helper()
	var body struct {
		Error struct {
			Code string `json:"code"`
		} `json:"error"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode error body %q: %v", rec.Body.String(), err)
	}
	return body.Error.Code
}

func TestLinkRoutesRefuseAMissingOrUnknownToken(t *testing.T) {
	recipes := &homeRecordingRecipeService{}
	router := linkRouter(recipes, account.Link{UUID: uuid.New(), HomeID: uuid.New()})

	cases := map[string]*http.Request{
		"no token":              linkRequest(http.MethodGet, "/link/v1/recipes", ""),
		"unknown token":         linkRequest(http.MethodGet, "/link/v1/meal-plan", "revoked-or-unknown"),
		"identity headers only": withIdentityHeaders(linkRequest(http.MethodGet, "/link/v1/recipes", "")),
		"basic scheme":          withHeader(linkRequest(http.MethodGet, "/link/v1/recipes", ""), "Authorization", "Basic "+linkToken),
		"two tokens": withHeader(linkRequest(http.MethodGet, "/link/v1/recipes", linkToken),
			"Authorization", "Bearer "+linkToken),
		"unrouted path": linkRequest(http.MethodGet, "/link/v1/anything", ""),
	}
	for name, req := range cases {
		t.Run(name, func(t *testing.T) {
			rec := httptest.NewRecorder()
			router.ServeHTTP(rec, req)

			if rec.Code != http.StatusUnauthorized {
				t.Errorf("status %d, want 401", rec.Code)
			}
			if code := errorCode(t, rec); code == "" {
				t.Errorf("401 body carries no error code: %s", rec.Body.String())
			}
		})
	}
	if len(recipes.homes) != 0 {
		t.Errorf("a refused request reached the recipe service %d times", len(recipes.homes))
	}
}

func TestLinkRoutesTakeTheHomeFromTheTokenAlone(t *testing.T) {
	homeA, homeB := uuid.New(), uuid.New()
	recipeID := uuid.New()
	recipes := &homeRecordingRecipeService{stubRecipeService: stubRecipeService{
		recipes: map[uuid.UUID]*recipe.Recipe{recipeID: {UUID: recipeID, Name: "Paella"}},
	}}
	router := linkRouter(recipes, account.Link{UUID: uuid.New(), HomeID: homeA, HomeName: "Home A"})

	for _, path := range []string{"/link/v1/recipes", "/link/v1/recipes/" + recipeID.String(), "/link/v1/meal-plan"} {
		req := withIdentityHeaders(linkRequest(http.MethodGet, path, linkToken))
		req.Header.Set(auth.HeaderHome, homeB.String())

		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)
		if rec.Code != http.StatusOK {
			t.Errorf("%s returned %d, want 200: %s", path, rec.Code, rec.Body.String())
		}
	}

	if len(recipes.homes) != 3 {
		t.Fatalf("the recipe service ran %d reads, want 3", len(recipes.homes))
	}
	for _, home := range recipes.homes {
		if home != homeA {
			t.Errorf("a read ran in home %s, want the token's home %s", home, homeA)
		}
	}
}

func TestLinkRoutesServeOnlyGET(t *testing.T) {
	recipes := &homeRecordingRecipeService{}
	router := linkRouter(recipes, account.Link{UUID: uuid.New(), HomeID: uuid.New()})
	id := uuid.New().String()

	for _, tc := range []struct{ method, path string }{
		{http.MethodPost, "/link/v1/recipes"},
		{http.MethodPut, "/link/v1/recipes/" + id},
		{http.MethodDelete, "/link/v1/recipes/" + id},
		{http.MethodPost, "/link/v1/meal-plan"},
		{http.MethodDelete, "/link/v1/meal-plan"},
	} {
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, linkRequest(tc.method, tc.path, linkToken))

		if rec.Code != http.StatusMethodNotAllowed {
			t.Errorf("%s %s returned %d, want 405", tc.method, tc.path, rec.Code)
		}
	}
	if len(recipes.homes) != 0 {
		t.Errorf("a non-GET request reached the recipe service %d times", len(recipes.homes))
	}
}

func TestLinkRecipeIndexNamesTheHomeAndListsCompactEntries(t *testing.T) {
	home := uuid.New()
	updated := time.Date(2026, 10, 1, 12, 0, 0, 0, time.UTC)
	withPhoto, withoutPhoto := uuid.New(), uuid.New()
	recipes := &homeRecordingRecipeService{stubRecipeService: stubRecipeService{index: []recipe.IndexEntry{
		{
			UUID:         withPhoto,
			Name:         "Paella",
			Labels:       []recipe.Label{{Type: recipe.LabelCuisine, Name: "spanish", CreatedAt: updated}},
			MainPhotoURL: "https://photos.example/paella.jpg",
			Url:          "https://recipes.example/paella",
			UpdatedAt:    updated,
		},
		{UUID: withoutPhoto, Name: "Toast", UpdatedAt: updated},
	}}}
	router := linkRouter(recipes, account.Link{UUID: uuid.New(), HomeID: home, HomeName: "Home A"})

	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, linkRequest(http.MethodGet, "/link/v1/recipes", linkToken))
	if rec.Code != http.StatusOK {
		t.Fatalf("status %d, want 200: %s", rec.Code, rec.Body.String())
	}

	var body map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if got := body["home"]; got.(map[string]any)["id"] != home.String() || got.(map[string]any)["name"] != "Home A" {
		t.Errorf("home is %v, want the token's home and its name", got)
	}

	entries := body["recipes"].([]any)
	if len(entries) != 2 {
		t.Fatalf("listed %d recipes, want 2", len(entries))
	}
	first := entries[0].(map[string]any)
	want := map[string]any{
		"id":        withPhoto.String(),
		"name":      "Paella",
		"labels":    []any{map[string]any{"type": "cuisine", "name": "spanish"}},
		"mainPhoto": "https://photos.example/paella.jpg",
		"url":       "https://recipes.example/paella",
		"updatedAt": "2026-10-01T12:00:00Z",
	}
	if a, b := mustJSON(t, first), mustJSON(t, want); a != b {
		t.Errorf("entry is %s, want %s", a, b)
	}

	second := entries[1].(map[string]any)
	if second["mainPhoto"] != nil {
		t.Errorf("a recipe with no photo has mainPhoto %v, want null", second["mainPhoto"])
	}
	if labels, ok := second["labels"].([]any); !ok || len(labels) != 0 {
		t.Errorf("a recipe with no labels has labels %v, want []", second["labels"])
	}
}

func TestLinkRecipeOutsideTheHomeIsNotFound(t *testing.T) {
	recipes := &homeRecordingRecipeService{}
	router := linkRouter(recipes, account.Link{UUID: uuid.New(), HomeID: uuid.New()})

	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, linkRequest(http.MethodGet, "/link/v1/recipes/"+uuid.New().String(), linkToken))

	if rec.Code != http.StatusNotFound {
		t.Errorf("status %d, want 404", rec.Code)
	}
	if code := errorCode(t, rec); code != "recipe_not_found" {
		t.Errorf("error code %q, want recipe_not_found", code)
	}
}

func TestLinkMealPlanIsAnEmptyListWhenNothingIsPlanned(t *testing.T) {
	router := linkRouter(&homeRecordingRecipeService{}, account.Link{UUID: uuid.New(), HomeID: uuid.New()})

	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, linkRequest(http.MethodGet, "/link/v1/meal-plan", linkToken))

	if got := rec.Body.String(); got != "{\"recipes\":[]}\n" {
		t.Errorf("body %q, want an empty recipes list", got)
	}
}

func withIdentityHeaders(r *http.Request) *http.Request {
	r.Header.Set(auth.HeaderUser, "forged-subject")
	r.Header.Set(auth.HeaderEmail, "forged@example.com")
	return r
}

func withHeader(r *http.Request, key, value string) *http.Request {
	r.Header.Add(key, value)
	return r
}

func mustJSON(t *testing.T, v any) string {
	t.Helper()
	b, err := json.Marshal(v)
	if err != nil {
		t.Fatal(err)
	}
	return string(b)
}
