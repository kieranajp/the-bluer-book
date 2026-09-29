package api

import (
	"bytes"
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"net/textproto"
	"os"
	"path/filepath"
	"reflect"
	"sort"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/kieranajp/the-bluer-book/internal/domain/pantry"
	"github.com/kieranajp/the-bluer-book/internal/domain/recipe"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/auth"
)

// The Flutter app's contract test reads the responses written here and writes
// the requests replayed here; each side owns the half it produces.
var updateContract = flag.Bool("update-contract", false, "rewrite the Go-owned contract fixtures")

const contractDir = "../../../testdata/contract"

type contractExchange struct {
	Method string          `json:"method"`
	Path   string          `json:"path"`
	Status int             `json:"status,omitempty"`
	Body   json.RawMessage `json:"body"`
}

var contractRecipeID = uuid.MustParse("7b0c6a52-3a8e-4f4e-9d1a-2f5a6c1e9b10")

func contractRecipe() recipe.Recipe {
	at := time.Date(2026, 3, 14, 18, 30, 0, 0, time.UTC)
	photo := recipe.Photo{URL: "https://img.example/lasagne.jpg", CreatedAt: at, UpdatedAt: at}
	return recipe.Recipe{
		UUID:         contractRecipeID,
		Name:         "Lasagne",
		Description:  "Layered and baked.",
		CookTime:     45,
		PrepTime:     30,
		Servings:     4,
		MainPhoto:    &photo,
		Url:          "https://example.com/lasagne",
		CreatedAt:    at,
		UpdatedAt:    at,
		IsInMealPlan: true,
		Steps: []recipe.Step{
			{Order: 1, Description: "Make the ragù.", Photos: []recipe.Photo{photo}, CreatedAt: at, UpdatedAt: at},
			{Order: 2, Description: "Layer and bake.", Photos: []recipe.Photo{}, CreatedAt: at, UpdatedAt: at},
		},
		Ingredients: []recipe.RecipeIngredient{
			{
				Ingredient:  recipe.Ingredient{Name: "beef mince", CreatedAt: at, UpdatedAt: at},
				Unit:        recipe.Unit{Name: "gram", Abbreviation: "g", CreatedAt: at, UpdatedAt: at},
				Quantity:    500,
				Preparation: "browned",
				Component:   "ragù",
			},
			{
				Ingredient: recipe.Ingredient{Name: "lasagne sheets", CreatedAt: at, UpdatedAt: at},
				Unit:       recipe.Unit{Name: "sheet", CreatedAt: at, UpdatedAt: at},
				Quantity:   2.5,
			},
		},
		Labels: []recipe.Label{{Type: "course", Name: "main", CreatedAt: at, UpdatedAt: at}},
		Photos: []recipe.Photo{photo},
	}
}

type contractRecipeService struct {
	stubRecipeService
	received []recipe.Recipe
}

func (s *contractRecipeService) GetRecipe(_ context.Context, id uuid.UUID) (*recipe.Recipe, error) {
	if id != contractRecipeID {
		return nil, recipe.RecipeNotFoundError{ID: id}
	}
	r := contractRecipe()
	return &r, nil
}

func (s *contractRecipeService) ListRecipes(context.Context, int, int, string, []string, string) ([]*recipe.Recipe, int, error) {
	r := contractRecipe()
	return []*recipe.Recipe{&r}, 1, nil
}

func (s *contractRecipeService) ListMealPlanRecipes(context.Context) ([]*recipe.Recipe, error) {
	r := contractRecipe()
	return []*recipe.Recipe{&r}, nil
}

func (s *contractRecipeService) CreateRecipe(_ context.Context, r recipe.Recipe) (*recipe.Recipe, error) {
	s.received = append(s.received, r)
	out := contractRecipe()
	return &out, nil
}

func (s *contractRecipeService) UpdateRecipe(_ context.Context, _ uuid.UUID, r recipe.Recipe) (*recipe.Recipe, error) {
	s.received = append(s.received, r)
	out := contractRecipe()
	return &out, nil
}

func (s *contractRecipeService) ListLabels(context.Context) ([]recipe.LabelSummary, error) {
	return []recipe.LabelSummary{{Type: "course", Name: "main", Uses: 3}, {Type: "diet", Name: "vegetarian", Uses: 1}}, nil
}

func (s *contractRecipeService) ListUnits(context.Context) ([]recipe.Unit, error) {
	at := time.Date(2026, 3, 14, 18, 30, 0, 0, time.UTC)
	return []recipe.Unit{{Name: "gram", Abbreviation: "g", CreatedAt: at, UpdatedAt: at}, {Name: "sheet", CreatedAt: at, UpdatedAt: at}}, nil
}

func (s *contractRecipeService) ListIngredients(context.Context) ([]recipe.Ingredient, error) {
	at := time.Date(2026, 3, 14, 18, 30, 0, 0, time.UTC)
	return []recipe.Ingredient{{Name: "beef mince", CreatedAt: at, UpdatedAt: at}}, nil
}

type contractUploader struct{}

func (contractUploader) UploadRecipePhoto(context.Context, string, []byte, string, string) (string, error) {
	return "https://img.example/uploaded.jpg", nil
}

func contractRouter(recipes *contractRecipeService, pantrySvc *stubPantryService) http.Handler {
	resolver := &stubResolver{session: auth.Session{UserID: uuid.New(), HomeID: uuid.New()}}
	photos := NewPhotoHandler(contractUploader{}, recipes, &noopLogger{})
	return NewRouter(recipes, pantrySvc, nil, nil, nil, photos, resolver, &noopLogger{})
}

func contractPantry() *stubPantryService {
	return &stubPantryService{
		items: []pantry.PantryItem{{Ingredient: "beef mince", AddedAt: time.Date(2026, 3, 14, 18, 30, 0, 0, time.UTC)}},
		shopping: []pantry.ShoppingListItem{
			{Name: "lasagne sheets", Source: pantry.ShoppingSourceMealPlan},
			{Name: "washing-up liquid", Source: pantry.ShoppingSourceCustom},
		},
	}
}

func serveContract(t *testing.T, router http.Handler, method, path, contentType string, body []byte) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(method, path, bytes.NewReader(body))
	req.Header.Set(auth.HeaderUser, "contract-subject")
	if contentType != "" {
		req.Header.Set("Content-Type", contentType)
	}
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	return rec
}

func TestContractResponsesMatchTheFixtures(t *testing.T) {
	recipePath := "/api/recipes/" + contractRecipeID.String()
	recipeBody, err := json.Marshal(contractRecipe())
	if err != nil {
		t.Fatal(err)
	}

	photoBody, photoType := contractPhotoUpload(t)

	cases := []struct {
		name, method, path, contentType string
		body                            []byte
		status                          int
	}{
		{name: "get_recipe", method: http.MethodGet, path: recipePath, status: http.StatusOK},
		{name: "list_recipes", method: http.MethodGet, path: "/api/recipes", status: http.StatusOK},
		{name: "list_meal_plan", method: http.MethodGet, path: "/api/recipes/meal-plan", status: http.StatusOK},
		{name: "create_recipe", method: http.MethodPost, path: "/api/recipes", contentType: "application/json", body: recipeBody, status: http.StatusCreated},
		{name: "update_recipe", method: http.MethodPut, path: recipePath, contentType: "application/json", body: recipeBody, status: http.StatusOK},
		{name: "list_labels", method: http.MethodGet, path: "/api/labels", status: http.StatusOK},
		{name: "list_units", method: http.MethodGet, path: "/api/units", status: http.StatusOK},
		{name: "list_ingredients", method: http.MethodGet, path: "/api/ingredients", status: http.StatusOK},
		{name: "list_pantry", method: http.MethodGet, path: "/api/pantry", status: http.StatusOK},
		{name: "shopping_list", method: http.MethodGet, path: "/api/shopping-list", status: http.StatusOK},
		{name: "add_shopping_item", method: http.MethodPost, path: "/api/shopping-list", contentType: "application/json", body: []byte(`{"name":"washing-up liquid"}`), status: http.StatusNoContent},
		{name: "upload_photo", method: http.MethodPost, path: recipePath + "/photo", contentType: photoType, body: photoBody, status: http.StatusOK},
		{name: "recipe_not_found", method: http.MethodGet, path: "/api/recipes/" + uuid.Nil.String(), status: http.StatusNotFound},
	}

	router := contractRouter(&contractRecipeService{}, contractPantry())
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			rec := serveContract(t, router, tc.method, tc.path, tc.contentType, tc.body)
			if rec.Code != tc.status {
				t.Fatalf("%s %s returned %d, want %d: %s", tc.method, tc.path, rec.Code, tc.status, rec.Body.String())
			}
			got := contractExchange{Method: tc.method, Path: tc.path, Status: rec.Code, Body: canonicalJSON(t, rec.Body.Bytes())}
			checkFixture(t, filepath.Join(contractDir, "responses", tc.name+".json"), got)
		})
	}
}

func contractPhotoUpload(t *testing.T) ([]byte, string) {
	t.Helper()
	var buf bytes.Buffer
	mw := multipart.NewWriter(&buf)
	header := textproto.MIMEHeader{}
	header.Set("Content-Disposition", `form-data; name="photo"; filename="lasagne.png"`)
	header.Set("Content-Type", "image/png")
	part, err := mw.CreatePart(header)
	if err != nil {
		t.Fatal(err)
	}
	part.Write([]byte("\x89PNG\r\n\x1a\n"))
	mw.Close()
	return buf.Bytes(), mw.FormDataContentType()
}

func TestContractRequestsFromTheAppAreUnderstood(t *testing.T) {
	cases := []struct {
		name   string
		verify func(t *testing.T, sent json.RawMessage, recipes *contractRecipeService, pantrySvc *stubPantryService)
	}{
		{name: "create_recipe", verify: verifyRecipeRequest},
		{name: "update_recipe", verify: verifyRecipeRequest},
		{name: "add_shopping_item", verify: func(t *testing.T, sent json.RawMessage, _ *contractRecipeService, pantrySvc *stubPantryService) {
			var body map[string]any
			json.Unmarshal(sent, &body)
			if len(pantrySvc.customAdded) != 1 || pantrySvc.customAdded[0] != body["name"] {
				t.Errorf("service received %v, want [%v]", pantrySvc.customAdded, body["name"])
			}
		}},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			ex := readFixture(t, filepath.Join(contractDir, "requests", tc.name+".json"))
			recipes, pantrySvc := &contractRecipeService{}, contractPantry()
			rec := serveContract(t, contractRouter(recipes, pantrySvc), ex.Method, ex.Path, "application/json", ex.Body)
			if rec.Code >= 300 {
				t.Fatalf("%s %s returned %d: %s", ex.Method, ex.Path, rec.Code, rec.Body.String())
			}
			tc.verify(t, ex.Body, recipes, pantrySvc)
		})
	}
}

// verifyRecipeRequest requires every key the app sends to be one Go decodes,
// and every value to survive the decode unchanged.
func verifyRecipeRequest(t *testing.T, sent json.RawMessage, recipes *contractRecipeService, _ *stubPantryService) {
	t.Helper()
	if len(recipes.received) != 1 {
		t.Fatalf("service received %d recipes, want 1", len(recipes.received))
	}
	decoded, err := json.Marshal(recipes.received[0])
	if err != nil {
		t.Fatal(err)
	}
	var want, got any
	json.Unmarshal(sent, &want)
	json.Unmarshal(decoded, &got)
	for _, problem := range sentButLost("$", want, got) {
		t.Error(problem)
	}
}

func sentButLost(at string, sent, decoded any) []string {
	switch s := sent.(type) {
	case map[string]any:
		d, ok := decoded.(map[string]any)
		if !ok {
			return []string{fmt.Sprintf("%s: sent an object, Go decoded %T", at, decoded)}
		}
		var out []string
		for _, k := range sortedKeys(s) {
			dv, known := d[k]
			if !known {
				out = append(out, fmt.Sprintf("%s.%s: sent by the app, unknown to Go", at, k))
				continue
			}
			out = append(out, sentButLost(at+"."+k, s[k], dv)...)
		}
		return out
	case []any:
		d, ok := decoded.([]any)
		if !ok || len(d) != len(s) {
			return []string{fmt.Sprintf("%s: sent %d items, Go decoded %v", at, len(s), decoded)}
		}
		var out []string
		for i := range s {
			out = append(out, sentButLost(fmt.Sprintf("%s[%d]", at, i), s[i], d[i])...)
		}
		return out
	default:
		if !reflect.DeepEqual(sent, decoded) {
			return []string{fmt.Sprintf("%s: sent %#v, Go decoded %#v", at, sent, decoded)}
		}
		return nil
	}
}

func sortedKeys(m map[string]any) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}

func canonicalJSON(t *testing.T, raw []byte) json.RawMessage {
	t.Helper()
	if len(raw) == 0 {
		return json.RawMessage("null")
	}
	var v any
	if err := json.Unmarshal(raw, &v); err != nil {
		t.Fatalf("response is not JSON: %v: %s", err, raw)
	}
	out, err := json.Marshal(v)
	if err != nil {
		t.Fatal(err)
	}
	return out
}

func readFixture(t *testing.T, path string) contractExchange {
	t.Helper()
	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read %s: %v", path, err)
	}
	var ex contractExchange
	if err := json.Unmarshal(raw, &ex); err != nil {
		t.Fatalf("decode %s: %v", path, err)
	}
	return ex
}

func checkFixture(t *testing.T, path string, got contractExchange) {
	t.Helper()
	if *updateContract {
		out, err := json.MarshalIndent(got, "", "  ")
		if err != nil {
			t.Fatal(err)
		}
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, append(out, '\n'), 0o644); err != nil {
			t.Fatal(err)
		}
		return
	}

	want := readFixture(t, path)
	var wantBody, gotBody any
	json.Unmarshal(want.Body, &wantBody)
	json.Unmarshal(got.Body, &gotBody)
	if want.Method != got.Method || want.Path != got.Path || want.Status != got.Status || !reflect.DeepEqual(wantBody, gotBody) {
		t.Errorf("%s is stale: the API now answers %s %s with %d %s\nrerun with -update-contract, then run the app's contract test", path, got.Method, got.Path, got.Status, got.Body)
	}
}
