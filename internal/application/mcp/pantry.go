package mcp

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	"github.com/kieranajp/the-bluer-book/internal/domain/pantry"
	mcplib "github.com/mark3labs/mcp-go/mcp"
)

func (h *RecipeMCPHandler) ListPantry(ctx context.Context, _ mcplib.CallToolRequest) (*mcplib.CallToolResult, error) {
	items, err := h.pantryService.ListPantry(ctx)
	if err != nil {
		h.logger.Error().Err(err).Msg("Failed to list pantry via MCP")
		return nil, fmt.Errorf("failed to list pantry: %w", err)
	}
	if items == nil {
		items = []pantry.PantryItem{}
	}

	responseJSON, err := json.Marshal(map[string]any{
		"items": items,
		"total": len(items),
	})
	if err != nil {
		return nil, fmt.Errorf("failed to encode pantry response: %w", err)
	}
	return mcplib.NewToolResultText(string(responseJSON)), nil
}

func (h *RecipeMCPHandler) AddToPantry(ctx context.Context, req mcplib.CallToolRequest) (*mcplib.CallToolResult, error) {
	ingredient, err := requiredTrimmedString(req, "ingredient")
	if err != nil {
		return nil, err
	}
	if err := h.pantryService.AddToPantry(ctx, ingredient); err != nil {
		if errors.Is(err, pantry.ErrIngredientNotFound) {
			h.logger.Warn().Str("ingredient", ingredient).Msg("Unknown ingredient for pantry add via MCP")
			return unknownIngredientResult(ingredient), nil
		}
		h.logger.Error().Err(err).Str("ingredient", ingredient).Msg("Failed to add ingredient to pantry via MCP")
		return nil, fmt.Errorf("failed to add ingredient to pantry: %w", err)
	}
	return successResult(fmt.Sprintf("Added '%s' to the pantry", ingredient), "ingredient", ingredient)
}

func (h *RecipeMCPHandler) RemoveFromPantry(ctx context.Context, req mcplib.CallToolRequest) (*mcplib.CallToolResult, error) {
	ingredient, err := requiredTrimmedString(req, "ingredient")
	if err != nil {
		return nil, err
	}
	if err := h.pantryService.RemoveFromPantry(ctx, ingredient); err != nil {
		if errors.Is(err, pantry.ErrIngredientNotFound) {
			h.logger.Warn().Str("ingredient", ingredient).Msg("Unknown ingredient for pantry removal via MCP")
			return unknownIngredientResult(ingredient), nil
		}
		h.logger.Error().Err(err).Str("ingredient", ingredient).Msg("Failed to remove ingredient from pantry via MCP")
		return nil, fmt.Errorf("failed to remove ingredient from pantry: %w", err)
	}
	return successResult(fmt.Sprintf("Removed '%s' from the pantry", ingredient), "ingredient", ingredient)
}

func (h *RecipeMCPHandler) ListShoppingList(ctx context.Context, _ mcplib.CallToolRequest) (*mcplib.CallToolResult, error) {
	items, err := h.pantryService.ShoppingList(ctx)
	if err != nil {
		h.logger.Error().Err(err).Msg("Failed to list shopping list via MCP")
		return nil, fmt.Errorf("failed to list shopping list: %w", err)
	}
	if items == nil {
		items = []pantry.ShoppingListItem{}
	}

	responseJSON, err := json.Marshal(map[string]any{
		"items": items,
		"total": len(items),
	})
	if err != nil {
		return nil, fmt.Errorf("failed to encode shopping list response: %w", err)
	}
	return mcplib.NewToolResultText(string(responseJSON)), nil
}

func (h *RecipeMCPHandler) AddToShoppingList(ctx context.Context, req mcplib.CallToolRequest) (*mcplib.CallToolResult, error) {
	name, err := requiredTrimmedString(req, "name")
	if err != nil {
		return nil, err
	}
	if err := h.pantryService.AddCustomShoppingItem(ctx, name); err != nil {
		h.logger.Error().Err(err).Str("name", name).Msg("Failed to add custom shopping-list item via MCP")
		return nil, fmt.Errorf("failed to add shopping-list item: %w", err)
	}
	return successResult(fmt.Sprintf("Added '%s' to the shopping list", name), "name", name)
}

func (h *RecipeMCPHandler) RemoveFromShoppingList(ctx context.Context, req mcplib.CallToolRequest) (*mcplib.CallToolResult, error) {
	name, err := requiredTrimmedString(req, "name")
	if err != nil {
		return nil, err
	}
	if err := h.pantryService.RemoveCustomShoppingItem(ctx, name); err != nil {
		h.logger.Error().Err(err).Str("name", name).Msg("Failed to remove custom shopping-list item via MCP")
		return nil, fmt.Errorf("failed to remove shopping-list item: %w", err)
	}
	return successResult(fmt.Sprintf("Removed '%s' from the shopping list", name), "name", name)
}

func (h *RecipeMCPHandler) SetIngredientStaple(ctx context.Context, req mcplib.CallToolRequest) (*mcplib.CallToolResult, error) {
	ingredient, err := requiredTrimmedString(req, "ingredient")
	if err != nil {
		return nil, err
	}
	staple := req.GetBool("staple", true)

	if err := h.pantryService.SetStaple(ctx, ingredient, staple); err != nil {
		if errors.Is(err, pantry.ErrIngredientNotFound) {
			h.logger.Warn().Str("ingredient", ingredient).Msg("Unknown ingredient for staple toggle via MCP")
			return unknownIngredientResult(ingredient), nil
		}
		h.logger.Error().Err(err).Str("ingredient", ingredient).Msg("Failed to set ingredient staple via MCP")
		return nil, fmt.Errorf("failed to set ingredient staple: %w", err)
	}

	message := fmt.Sprintf("Marked '%s' as a staple — it won't appear on shopping lists", ingredient)
	if !staple {
		message = fmt.Sprintf("'%s' is no longer a staple", ingredient)
	}
	return successResult(message, "ingredient", ingredient)
}

// unknownIngredientResult tells the caller the pantry didn't change and why.
// It's a tool error rather than a transport error so the model reads the text
// and can correct itself — the usual fix is a name lifted from a recipe, or
// add_to_shopping_list for something that isn't a recipe ingredient at all.
func unknownIngredientResult(ingredient string) *mcplib.CallToolResult {
	return mcplib.NewToolResultError(fmt.Sprintf(
		"No ingredient called '%s' exists, so the pantry was not changed. The pantry only holds ingredients that recipes in the book already use — check the spelling against a recipe's ingredient list, or use add_to_shopping_list if this isn't a recipe ingredient.",
		ingredient,
	))
}

func requiredTrimmedString(req mcplib.CallToolRequest, key string) (string, error) {
	value := strings.TrimSpace(req.GetString(key, ""))
	if value == "" {
		return "", fmt.Errorf("%s is required", key)
	}
	return value, nil
}

func successResult(message, key, value string) (*mcplib.CallToolResult, error) {
	responseJSON, err := json.Marshal(map[string]any{
		"success": true,
		"message": message,
		key:       value,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to encode success response: %w", err)
	}
	return mcplib.NewToolResultText(string(responseJSON)), nil
}
