// Package ai holds integrations with Google's Gemini models that sit outside
// the conversational chat agent — one-shot, structured calls like turning a
// photo of a handwritten shopping list into a tidy list of item names.
package ai

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"google.golang.org/genai"

	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
)

// scanPrompt instructs Gemini to read a photo of a shopping list and return
// just the item names. Kept deliberately strict — no quantities, no prices, no
// section headings — because the shopping list is presence-only.
const scanPrompt = `You are reading a photo of a shopping list. It may be handwritten or printed.
Extract every distinct item the person needs to buy.
Return ONLY the item names, lowercased, with no quantities, prices, units, bullet points, or section headings.
Normalise obvious abbreviations to a sensible full name (e.g. "w/up liquid" -> "washing-up liquid").
Ignore crossed-out items, dates, totals, and anything that isn't a thing to buy.
If the image contains no legible shopping list, return an empty list.`

// ShoppingListScanner turns a photo into a list of shopping item names via
// Gemini's multimodal model with a structured (JSON array) response.
type ShoppingListScanner struct {
	client *genai.Client
	model  string
	logger logger.Logger
}

// NewShoppingListScanner builds a scanner backed by the given Gemini model.
// Reuses the same Google AI Studio API key as the chat handler.
func NewShoppingListScanner(ctx context.Context, apiKey, model string, log logger.Logger) (*ShoppingListScanner, error) {
	if apiKey == "" {
		return nil, fmt.Errorf("google API key is required for the shopping list scanner")
	}
	client, err := genai.NewClient(ctx, &genai.ClientConfig{APIKey: apiKey})
	if err != nil {
		return nil, fmt.Errorf("creating gemini client: %w", err)
	}
	return &ShoppingListScanner{client: client, model: model, logger: log}, nil
}

// Scan reads the image and returns the de-duplicated, trimmed item names it
// found. The order follows the model's reading of the list.
func (s *ShoppingListScanner) Scan(ctx context.Context, image []byte, mimeType string) ([]string, error) {
	contents := []*genai.Content{
		genai.NewContentFromParts([]*genai.Part{
			genai.NewPartFromText(scanPrompt),
			genai.NewPartFromBytes(image, mimeType),
		}, genai.RoleUser),
	}

	config := &genai.GenerateContentConfig{
		ResponseMIMEType: "application/json",
		ResponseSchema: &genai.Schema{
			Type:  genai.TypeArray,
			Items: &genai.Schema{Type: genai.TypeString},
		},
	}

	resp, err := s.client.Models.GenerateContent(ctx, s.model, contents, config)
	if err != nil {
		return nil, fmt.Errorf("gemini generate content: %w", err)
	}

	raw := resp.Text()
	var parsed []string
	if err := json.Unmarshal([]byte(raw), &parsed); err != nil {
		s.logger.Error().Err(err).Str("response", raw).Msg("Failed to parse scanned shopping list")
		return nil, fmt.Errorf("parsing model response: %w", err)
	}

	// Trim, drop blanks, and de-dupe case-insensitively while preserving order.
	seen := make(map[string]struct{}, len(parsed))
	items := make([]string, 0, len(parsed))
	for _, name := range parsed {
		name = strings.TrimSpace(name)
		if name == "" {
			continue
		}
		key := strings.ToLower(name)
		if _, dup := seen[key]; dup {
			continue
		}
		seen[key] = struct{}{}
		items = append(items, name)
	}

	return items, nil
}
