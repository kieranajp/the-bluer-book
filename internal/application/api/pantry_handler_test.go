package api

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/kieranajp/the-bluer-book/internal/domain/pantry"
)

// --- Stub ---

type stubPantryService struct {
	items         []pantry.PantryItem
	shopping      []pantry.ShoppingListItem
	err           error
	added         []string
	removed       []string
	customAdded   []string
	customRemoved []string
}

func (s *stubPantryService) AddToPantry(_ context.Context, ingredient string) error {
	if s.err != nil {
		return s.err
	}
	s.added = append(s.added, ingredient)
	return nil
}

func (s *stubPantryService) RemoveFromPantry(_ context.Context, ingredient string) error {
	if s.err != nil {
		return s.err
	}
	s.removed = append(s.removed, ingredient)
	return nil
}

func (s *stubPantryService) ListPantry(_ context.Context) ([]pantry.PantryItem, error) {
	return s.items, s.err
}

func (s *stubPantryService) ShoppingList(_ context.Context) ([]pantry.ShoppingListItem, error) {
	return s.shopping, s.err
}

func (s *stubPantryService) AddCustomShoppingItem(_ context.Context, name string) error {
	if s.err != nil {
		return s.err
	}
	s.customAdded = append(s.customAdded, name)
	return nil
}

func (s *stubPantryService) RemoveCustomShoppingItem(_ context.Context, name string) error {
	if s.err != nil {
		return s.err
	}
	s.customRemoved = append(s.customRemoved, name)
	return nil
}

// --- Tests ---

func TestListPantry_Success(t *testing.T) {
	svc := &stubPantryService{
		items: []pantry.PantryItem{{Ingredient: "flour"}, {Ingredient: "salt"}},
	}
	h := NewPantryHandler(svc, nil, &noopLogger{})

	req := httptest.NewRequest(http.MethodGet, "/api/pantry", nil)
	rec := httptest.NewRecorder()
	h.ListPantry(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}

	var body struct {
		Items []struct {
			Ingredient string `json:"ingredient"`
		} `json:"items"`
		Total int `json:"total"`
	}
	if err := json.NewDecoder(rec.Body).Decode(&body); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if body.Total != 2 || len(body.Items) != 2 {
		t.Fatalf("expected 2 items, got total=%d len=%d", body.Total, len(body.Items))
	}
	if body.Items[0].Ingredient != "flour" {
		t.Errorf("expected first item %q, got %q", "flour", body.Items[0].Ingredient)
	}
}

func TestListPantry_ServiceError(t *testing.T) {
	svc := &stubPantryService{err: errors.New("db down")}
	h := NewPantryHandler(svc, nil, &noopLogger{})

	req := httptest.NewRequest(http.MethodGet, "/api/pantry", nil)
	rec := httptest.NewRecorder()
	h.ListPantry(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("expected 500, got %d", rec.Code)
	}
}

type shoppingListBody struct {
	Items []pantry.ShoppingListItem `json:"items"`
	Total int                       `json:"total"`
}

func TestShoppingList_Success(t *testing.T) {
	svc := &stubPantryService{shopping: []pantry.ShoppingListItem{
		{Name: "eggs", Source: pantry.ShoppingSourceMealPlan},
		{Name: "washing-up liquid", Source: pantry.ShoppingSourceCustom},
	}}
	h := NewPantryHandler(svc, nil, &noopLogger{})

	req := httptest.NewRequest(http.MethodGet, "/api/shopping-list", nil)
	rec := httptest.NewRecorder()
	h.ShoppingList(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}

	var body shoppingListBody
	if err := json.NewDecoder(rec.Body).Decode(&body); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if body.Total != 2 || len(body.Items) != 2 {
		t.Fatalf("expected 2 items, got total=%d len=%d", body.Total, len(body.Items))
	}
	if body.Items[0].Name != "eggs" || body.Items[0].Source != pantry.ShoppingSourceMealPlan {
		t.Errorf("expected first item eggs/meal_plan, got %q/%q", body.Items[0].Name, body.Items[0].Source)
	}
	if body.Items[1].Source != pantry.ShoppingSourceCustom {
		t.Errorf("expected second item to be custom, got %q", body.Items[1].Source)
	}
}

func TestShoppingList_EmptyIsArrayNotNull(t *testing.T) {
	svc := &stubPantryService{shopping: nil}
	h := NewPantryHandler(svc, nil, &noopLogger{})

	req := httptest.NewRequest(http.MethodGet, "/api/shopping-list", nil)
	rec := httptest.NewRecorder()
	h.ShoppingList(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
	var body shoppingListBody
	if err := json.NewDecoder(rec.Body).Decode(&body); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if body.Items == nil {
		t.Errorf("expected items to be [] not null")
	}
	if body.Total != 0 {
		t.Errorf("expected total 0, got %d", body.Total)
	}
}

func TestAddCustomShoppingItem_Success(t *testing.T) {
	svc := &stubPantryService{}
	h := NewPantryHandler(svc, nil, &noopLogger{})

	req := httptest.NewRequest(http.MethodPost, "/api/shopping-list",
		strings.NewReader(`{"name":"washing-up liquid"}`))
	rec := httptest.NewRecorder()
	h.AddCustomShoppingItem(rec, req)

	if rec.Code != http.StatusNoContent {
		t.Fatalf("expected 204, got %d", rec.Code)
	}
	if len(svc.customAdded) != 1 || svc.customAdded[0] != "washing-up liquid" {
		t.Errorf("expected custom item added, got %v", svc.customAdded)
	}
}

func TestAddCustomShoppingItem_MissingName(t *testing.T) {
	svc := &stubPantryService{}
	h := NewPantryHandler(svc, nil, &noopLogger{})

	req := httptest.NewRequest(http.MethodPost, "/api/shopping-list",
		strings.NewReader(`{"name":"  "}`))
	rec := httptest.NewRecorder()
	h.AddCustomShoppingItem(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}
}

func TestRemoveCustomShoppingItem_Success(t *testing.T) {
	svc := &stubPantryService{}
	h := NewPantryHandler(svc, nil, &noopLogger{})

	req := httptest.NewRequest(http.MethodDelete, "/api/shopping-list/washing-up%20liquid", nil)
	req.SetPathValue("name", "washing-up liquid")
	rec := httptest.NewRecorder()
	h.RemoveCustomShoppingItem(rec, req)

	if rec.Code != http.StatusNoContent {
		t.Fatalf("expected 204, got %d", rec.Code)
	}
	if len(svc.customRemoved) != 1 || svc.customRemoved[0] != "washing-up liquid" {
		t.Errorf("expected custom item removed, got %v", svc.customRemoved)
	}
}

func TestScanShoppingList_Unavailable(t *testing.T) {
	svc := &stubPantryService{}
	h := NewPantryHandler(svc, nil, &noopLogger{}) // nil scanner

	req := httptest.NewRequest(http.MethodPost, "/api/shopping-list/scan", nil)
	rec := httptest.NewRecorder()
	h.ScanShoppingList(rec, req)

	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("expected 503, got %d", rec.Code)
	}
}

func TestShoppingList_ServiceError(t *testing.T) {
	svc := &stubPantryService{err: errors.New("db down")}
	h := NewPantryHandler(svc, nil, &noopLogger{})

	req := httptest.NewRequest(http.MethodGet, "/api/shopping-list", nil)
	rec := httptest.NewRecorder()
	h.ShoppingList(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("expected 500, got %d", rec.Code)
	}
}

func TestAddToPantry_Success(t *testing.T) {
	svc := &stubPantryService{}
	h := NewPantryHandler(svc, nil, &noopLogger{})

	req := httptest.NewRequest(http.MethodPut, "/api/pantry/flour", nil)
	req.SetPathValue("ingredient", "flour")
	rec := httptest.NewRecorder()
	h.AddToPantry(rec, req)

	if rec.Code != http.StatusNoContent {
		t.Fatalf("expected 204, got %d", rec.Code)
	}
	if len(svc.added) != 1 || svc.added[0] != "flour" {
		t.Errorf("expected flour added, got %v", svc.added)
	}
}

func TestAddToPantry_MissingIngredient(t *testing.T) {
	svc := &stubPantryService{}
	h := NewPantryHandler(svc, nil, &noopLogger{})

	req := httptest.NewRequest(http.MethodPut, "/api/pantry/", nil)
	rec := httptest.NewRecorder()
	h.AddToPantry(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}
}

func TestRemoveFromPantry_Success(t *testing.T) {
	svc := &stubPantryService{}
	h := NewPantryHandler(svc, nil, &noopLogger{})

	req := httptest.NewRequest(http.MethodDelete, "/api/pantry/salt", nil)
	req.SetPathValue("ingredient", "salt")
	rec := httptest.NewRecorder()
	h.RemoveFromPantry(rec, req)

	if rec.Code != http.StatusNoContent {
		t.Fatalf("expected 204, got %d", rec.Code)
	}
	if len(svc.removed) != 1 || svc.removed[0] != "salt" {
		t.Errorf("expected salt removed, got %v", svc.removed)
	}
}
