package mcp

import (
	"context"
	"encoding/json"
	"errors"
	"strings"
	"testing"

	"github.com/kieranajp/the-bluer-book/internal/domain/pantry"
	mcplib "github.com/mark3labs/mcp-go/mcp"
	"github.com/rs/zerolog"
)

type stubPantryService struct {
	pantryItems     []pantry.PantryItem
	shoppingList    []pantry.ShoppingListItem
	addedPantry     string
	removedPantry   string
	addedShopping   string
	removedShopping string
	err             error
}

func (s *stubPantryService) AddToPantry(_ context.Context, ingredient string) error {
	s.addedPantry = ingredient
	return s.err
}

func (s *stubPantryService) RemoveFromPantry(_ context.Context, ingredient string) error {
	s.removedPantry = ingredient
	return s.err
}

func (s *stubPantryService) ListPantry(context.Context) ([]pantry.PantryItem, error) {
	return s.pantryItems, s.err
}

func (s *stubPantryService) ShoppingList(context.Context) ([]pantry.ShoppingListItem, error) {
	return s.shoppingList, s.err
}

func (s *stubPantryService) AddCustomShoppingItem(_ context.Context, name string) error {
	s.addedShopping = name
	return s.err
}

func (s *stubPantryService) RemoveCustomShoppingItem(_ context.Context, name string) error {
	s.removedShopping = name
	return s.err
}

type noopLogger struct{}

var testLogger = zerolog.Nop()

func (noopLogger) Info() *zerolog.Event  { return testLogger.Info() }
func (noopLogger) Debug() *zerolog.Event { return testLogger.Debug() }
func (noopLogger) Warn() *zerolog.Event  { return testLogger.Warn() }
func (noopLogger) Error() *zerolog.Event { return testLogger.Error() }

func toolRequest(arguments map[string]any) mcplib.CallToolRequest {
	return mcplib.CallToolRequest{
		Params: mcplib.CallToolParams{Arguments: arguments},
	}
}

func resultJSON(t *testing.T, result *mcplib.CallToolResult) map[string]any {
	t.Helper()
	content, ok := result.Content[0].(mcplib.TextContent)
	if !ok {
		t.Fatalf("result content type = %T, want mcp.TextContent", result.Content[0])
	}
	var body map[string]any
	if err := json.Unmarshal([]byte(content.Text), &body); err != nil {
		t.Fatalf("decode result: %v", err)
	}
	return body
}

func TestListPantry(t *testing.T) {
	svc := &stubPantryService{
		pantryItems: []pantry.PantryItem{{Ingredient: "flour"}, {Ingredient: "salt"}},
	}
	handler := NewRecipeMCPHandler(nil, svc, noopLogger{})

	result, err := handler.ListPantry(context.Background(), toolRequest(nil))
	if err != nil {
		t.Fatalf("ListPantry() error = %v", err)
	}
	body := resultJSON(t, result)
	if body["total"] != float64(2) {
		t.Fatalf("total = %v, want 2", body["total"])
	}
}

func TestListShoppingList(t *testing.T) {
	svc := &stubPantryService{
		shoppingList: []pantry.ShoppingListItem{
			{Name: "eggs", Source: pantry.ShoppingSourceMealPlan},
			{Name: "soap", Source: pantry.ShoppingSourceCustom},
		},
	}
	handler := NewRecipeMCPHandler(nil, svc, noopLogger{})

	result, err := handler.ListShoppingList(context.Background(), toolRequest(nil))
	if err != nil {
		t.Fatalf("ListShoppingList() error = %v", err)
	}
	body := resultJSON(t, result)
	if body["total"] != float64(2) {
		t.Fatalf("total = %v, want 2", body["total"])
	}
}

func TestPantryAndShoppingListMutations(t *testing.T) {
	tests := []struct {
		name string
		call func(*RecipeMCPHandler) (*mcplib.CallToolResult, error)
		got  func(*stubPantryService) string
		want string
	}{
		{
			name: "add pantry",
			call: func(h *RecipeMCPHandler) (*mcplib.CallToolResult, error) {
				return h.AddToPantry(context.Background(), toolRequest(map[string]any{"ingredient": " flour "}))
			},
			got:  func(s *stubPantryService) string { return s.addedPantry },
			want: "flour",
		},
		{
			name: "remove pantry",
			call: func(h *RecipeMCPHandler) (*mcplib.CallToolResult, error) {
				return h.RemoveFromPantry(context.Background(), toolRequest(map[string]any{"ingredient": "salt"}))
			},
			got:  func(s *stubPantryService) string { return s.removedPantry },
			want: "salt",
		},
		{
			name: "add shopping item",
			call: func(h *RecipeMCPHandler) (*mcplib.CallToolResult, error) {
				return h.AddToShoppingList(context.Background(), toolRequest(map[string]any{"name": " soap "}))
			},
			got:  func(s *stubPantryService) string { return s.addedShopping },
			want: "soap",
		},
		{
			name: "remove shopping item",
			call: func(h *RecipeMCPHandler) (*mcplib.CallToolResult, error) {
				return h.RemoveFromShoppingList(context.Background(), toolRequest(map[string]any{"name": "soap"}))
			},
			got:  func(s *stubPantryService) string { return s.removedShopping },
			want: "soap",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			svc := &stubPantryService{}
			handler := NewRecipeMCPHandler(nil, svc, noopLogger{})
			result, err := tt.call(handler)
			if err != nil {
				t.Fatalf("tool call error = %v", err)
			}
			if got := tt.got(svc); got != tt.want {
				t.Fatalf("service argument = %q, want %q", got, tt.want)
			}
			if success := resultJSON(t, result)["success"]; success != true {
				t.Fatalf("success = %v, want true", success)
			}
		})
	}
}

func TestPantryToolsValidateAndWrapErrors(t *testing.T) {
	handler := NewRecipeMCPHandler(nil, &stubPantryService{}, noopLogger{})
	if _, err := handler.AddToPantry(context.Background(), toolRequest(map[string]any{"ingredient": "  "})); err == nil {
		t.Fatal("AddToPantry() error = nil, want required-field error")
	}

	handler = NewRecipeMCPHandler(nil, &stubPantryService{err: errors.New("db down")}, noopLogger{})
	_, err := handler.ListPantry(context.Background(), toolRequest(nil))
	if err == nil || !strings.Contains(err.Error(), "failed to list pantry") {
		t.Fatalf("ListPantry() error = %v, want wrapped context", err)
	}
}
