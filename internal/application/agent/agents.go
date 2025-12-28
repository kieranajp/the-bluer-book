package agent

import (
	"context"
	"encoding/json"
	"fmt"
	"log"

	"github.com/kieranajp/the-bluer-book/internal/domain/recipe/service"
	"google.golang.org/adk/agent"
	"google.golang.org/adk/agent/llmagent"
	"google.golang.org/adk/model"
	"google.golang.org/adk/model/gemini"
	"google.golang.org/adk/tool"
	"google.golang.org/adk/tool/agenttool"
	"google.golang.org/genai"
)

func NewCookingAgent(ctx context.Context, mdl model.LLM, recipeService service.RecipeService) (agent.Agent, error) {
	searchTool, err := NewSearchRecipesTool(recipeService)
	if err != nil {
		return nil, fmt.Errorf("failed to create search tool: %w", err)
	}

	getTool, err := NewGetRecipeTool(recipeService)
	if err != nil {
		return nil, fmt.Errorf("failed to create get recipe tool: %w", err)
	}

	return llmagent.New(llmagent.Config{
		Name:        "cooking_agent",
		Model:       mdl,
		Description: "Cooking and recipe specialist.",
		Instruction: "You are a cooking specialist. Use search_recipes to find recipes. Use get_recipe to show full recipe details. Only recommend recipes from the database - if no matches are found, say so.",
		Tools: []tool.Tool{
			searchTool,
			getTool,
		},
		BeforeAgentCallbacks: []agent.BeforeAgentCallback{
			func(ctx agent.CallbackContext) (*genai.Content, error) {
				log.Printf("[COOKING_AGENT] Received request: %v", ctx.UserContent())
				return nil, nil
			},
		},
		AfterAgentCallbacks: []agent.AfterAgentCallback{
			func(ctx agent.CallbackContext) (*genai.Content, error) {
				log.Printf("[COOKING_AGENT] Agent completed")
				return nil, nil
			},
		},
		AfterModelCallbacks: []llmagent.AfterModelCallback{
			func(ctx agent.CallbackContext, resp *model.LLMResponse, err error) (*model.LLMResponse, error) {
				if resp != nil && resp.Content != nil {
					for _, part := range resp.Content.Parts {
						if part.Text != "" {
							log.Printf("[COOKING_AGENT] LLM text response: %d chars", len(part.Text))
						}
					}
				}
				return nil, nil
			},
		},
		BeforeToolCallbacks: []llmagent.BeforeToolCallback{
			func(ctx tool.Context, t tool.Tool, args map[string]any) (map[string]any, error) {
				argsJSON, _ := json.Marshal(args)
				log.Printf("[COOKING_AGENT] Calling %s with: %s", t.Name(), argsJSON)
				return nil, nil
			},
		},
		AfterToolCallbacks: []llmagent.AfterToolCallback{
			func(ctx tool.Context, t tool.Tool, args, result map[string]any, err error) (map[string]any, error) {
				if err != nil {
					log.Printf("[COOKING_AGENT] Tool %s error: %v", t.Name(), err)
				} else {
					resultJSON, _ := json.Marshal(result)
					log.Printf("[COOKING_AGENT] Tool %s returned: %s", t.Name(), resultJSON)
				}
				return nil, nil
			},
		},
	})
}

func NewRootAgent(ctx context.Context, apiKey string, recipeService service.RecipeService) (agent.Agent, error) {
	mdl, err := gemini.NewModel(ctx, "gemini-3-flash-preview", &genai.ClientConfig{
		APIKey: apiKey,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to create Gemini model: %w", err)
	}

	cookingAgent, err := NewCookingAgent(ctx, mdl, recipeService)
	if err != nil {
		return nil, fmt.Errorf("failed to create cooking agent: %w", err)
	}

	return llmagent.New(llmagent.Config{
		Name:        "root_agent",
		Model:       mdl,
		Description: "General conversational agent that routes to specialist agents.",
		Instruction: `You are a helpful routing assistant.

For ANY questions about recipes, cooking, food, or ingredients, use the cooking_agent tool.
For general conversation, answer directly.

Only share information returned by tools. Do not fabricate recipes or cooking information.`,
		Tools: []tool.Tool{
			agenttool.New(cookingAgent, nil),
		},
		BeforeToolCallbacks: []llmagent.BeforeToolCallback{
			func(ctx tool.Context, t tool.Tool, args map[string]any) (map[string]any, error) {
				argsJSON, _ := json.Marshal(args)
				log.Printf("[ROOT_AGENT] Delegating to %s with: %s", t.Name(), argsJSON)
				return nil, nil
			},
		},
		AfterToolCallbacks: []llmagent.AfterToolCallback{
			func(ctx tool.Context, t tool.Tool, args, result map[string]any, err error) (map[string]any, error) {
				if err != nil {
					log.Printf("[ROOT_AGENT] Tool %s error: %v", t.Name(), err)
				} else {
					resultJSON, _ := json.Marshal(result)
					log.Printf("[ROOT_AGENT] Tool %s returned: %s", t.Name(), resultJSON)
				}
				return nil, nil
			},
		},
	})
}
