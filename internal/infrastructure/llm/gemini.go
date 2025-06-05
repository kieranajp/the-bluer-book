package llm

import (
	"context"
	_ "embed"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"

	"github.com/kieranajp/the-bluer-book/internal/domain/recipe"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/trello"
)

const (
	geminiAPIURL    = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=%s"
	contentTypeJSON = "application/json"
)

var (
	//go:embed prompts/normalise_prompt.txt
	normalisePrompt string
)

// HTTPClient is an interface for *http.Client (for testability)
type HTTPClient interface {
	Do(req *http.Request) (*http.Response, error)
}

type GeminiClient struct {
	APIKey string
	log    logger.Logger
	client HTTPClient
}

func NewGeminiClient(apiKey string, log logger.Logger, client HTTPClient) *GeminiClient {
	return &GeminiClient{APIKey: apiKey, log: log, client: client}
}

func (g *GeminiClient) NormaliseRecipe(ctx context.Context, card trello.Card) (recipe.Recipe, error) {
	cardJSON, err := json.Marshal(card)
	if err != nil {
		return recipe.Recipe{}, err
	}

	prompt := strings.Replace(normalisePrompt, "{{CARD_JSON}}", string(cardJSON), 1)
	resp, err := g.prompt(ctx, prompt)
	if err != nil {
		return recipe.Recipe{}, err
	}

	jsonStr, err := g.extractJson(resp)
	if err != nil {
		return recipe.Recipe{}, err
	}

	var rec recipe.Recipe
	err = json.Unmarshal([]byte(jsonStr), &rec)
	if err != nil {
		return recipe.Recipe{}, fmt.Errorf("failed to unmarshal Gemini response: %w", err)
	}

	return rec, nil
}

func (g *GeminiClient) extractJson(input string) (string, error) {
	// Find the first { or [ and the last } or ]
	start := -1
	end := -1

	// Look for object start/end
	objStart := strings.Index(input, "{")
	objEnd := strings.LastIndex(input, "}")

	// Look for array start/end
	arrStart := strings.Index(input, "[")
	arrEnd := strings.LastIndex(input, "]")

	// Determine which comes first and is a complete pair
	if objStart != -1 && objEnd != -1 && (arrStart == -1 || objStart < arrStart) {
		start = objStart
		end = objEnd
	} else if arrStart != -1 && arrEnd != -1 {
		start = arrStart
		end = arrEnd
	}

	if start == -1 || end == -1 || start > end {
		return "", fmt.Errorf("no valid JSON found in response")
	}

	jsonStr := input[start : end+1]

	// Validate that it's actually valid JSON
	var js json.RawMessage
	if err := json.Unmarshal([]byte(jsonStr), &js); err != nil {
		return "", fmt.Errorf("extracted content is not valid JSON: %w", err)
	}

	return jsonStr, nil
}

func (g *GeminiClient) prompt(ctx context.Context, prompt string) (string, error) {
	g.log.Debug().Str("prompt", prompt).Msg("Prompting Gemini")

	url := fmt.Sprintf(geminiAPIURL, g.APIKey)

	requestBody := map[string]interface{}{
		"contents": []map[string]interface{}{
			{
				"parts": []map[string]string{
					{"text": prompt},
				},
			},
		},
	}
	jsonBody, err := json.Marshal(requestBody)
	if err != nil {
		return "", err
	}

	req, err := http.NewRequestWithContext(ctx, "POST", url, strings.NewReader(string(jsonBody)))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", contentTypeJSON)

	resp, err := g.client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("error when requesting Gemini API: %s", string(body))
	}

	var geminiResp struct {
		Candidates []struct {
			Content struct {
				Parts []struct {
					Text string `json:"text"`
				} `json:"parts"`
			} `json:"content"`
		} `json:"candidates"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&geminiResp); err != nil {
		return "", err
	}

	return geminiResp.Candidates[0].Content.Parts[0].Text, nil
}
