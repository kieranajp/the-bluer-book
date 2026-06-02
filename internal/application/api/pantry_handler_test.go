package api

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/kieranajp/the-bluer-book/internal/domain/pantry"
)

// --- Stub ---

type stubPantryService struct {
	items    []pantry.PantryItem
	shopping []string
	err      error
	added    []string
	removed  []string
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

func (s *stubPantryService) ShoppingList(_ context.Context) ([]string, error) {
	return s.shopping, s.err
}

// --- Tests ---

func TestListPantry_Success(t *testing.T) {
	svc := &stubPantryService{
		items: []pantry.PantryItem{{Ingredient: "flour"}, {Ingredient: "salt"}},
	}
	h := NewPantryHandler(svc, &noopLogger{})

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
	h := NewPantryHandler(svc, &noopLogger{})

	req := httptest.NewRequest(http.MethodGet, "/api/pantry", nil)
	rec := httptest.NewRecorder()
	h.ListPantry(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("expected 500, got %d", rec.Code)
	}
}

func TestShoppingList_Success(t *testing.T) {
	svc := &stubPantryService{shopping: []string{"eggs", "milk"}}
	h := NewPantryHandler(svc, &noopLogger{})

	req := httptest.NewRequest(http.MethodGet, "/api/shopping-list", nil)
	rec := httptest.NewRecorder()
	h.ShoppingList(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}

	var body struct {
		Items []string `json:"items"`
		Total int      `json:"total"`
	}
	if err := json.NewDecoder(rec.Body).Decode(&body); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if body.Total != 2 || len(body.Items) != 2 {
		t.Fatalf("expected 2 items, got total=%d len=%d", body.Total, len(body.Items))
	}
	if body.Items[0] != "eggs" {
		t.Errorf("expected first item %q, got %q", "eggs", body.Items[0])
	}
}

func TestShoppingList_EmptyIsArrayNotNull(t *testing.T) {
	svc := &stubPantryService{shopping: nil}
	h := NewPantryHandler(svc, &noopLogger{})

	req := httptest.NewRequest(http.MethodGet, "/api/shopping-list", nil)
	rec := httptest.NewRecorder()
	h.ShoppingList(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
	var body struct {
		Items []string `json:"items"`
		Total int      `json:"total"`
	}
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

func TestShoppingList_ServiceError(t *testing.T) {
	svc := &stubPantryService{err: errors.New("db down")}
	h := NewPantryHandler(svc, &noopLogger{})

	req := httptest.NewRequest(http.MethodGet, "/api/shopping-list", nil)
	rec := httptest.NewRecorder()
	h.ShoppingList(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("expected 500, got %d", rec.Code)
	}
}

func TestAddToPantry_Success(t *testing.T) {
	svc := &stubPantryService{}
	h := NewPantryHandler(svc, &noopLogger{})

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
	h := NewPantryHandler(svc, &noopLogger{})

	req := httptest.NewRequest(http.MethodPut, "/api/pantry/", nil)
	rec := httptest.NewRecorder()
	h.AddToPantry(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}
}

func TestRemoveFromPantry_Success(t *testing.T) {
	svc := &stubPantryService{}
	h := NewPantryHandler(svc, &noopLogger{})

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
