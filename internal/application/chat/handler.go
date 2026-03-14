package chat

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"sync"
	"time"

	gomcp "github.com/modelcontextprotocol/go-sdk/mcp"
	"google.golang.org/adk/agent"
	"google.golang.org/adk/agent/llmagent"
	"google.golang.org/adk/model/gemini"
	"google.golang.org/adk/runner"
	"google.golang.org/adk/session"
	"google.golang.org/adk/tool"
	"google.golang.org/adk/tool/mcptoolset"
	"google.golang.org/genai"

	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
)

type Handler struct {
	runner         *runner.Runner
	sessionService session.Service
	logger         logger.Logger
	mu             sync.Mutex
}

type chatRequest struct {
	Message   string `json:"message"`
	SessionID string `json:"session_id,omitempty"`
}

type chatEvent struct {
	Content   string `json:"content"`
	Done      bool   `json:"done"`
	SessionID string `json:"session_id,omitempty"`
}

func NewHandler(mcpAddr string, log logger.Logger) (*Handler, error) {
	ctx := context.Background()

	apiKey := os.Getenv("GOOGLE_API_KEY")
	if apiKey == "" {
		return nil, fmt.Errorf("GOOGLE_API_KEY environment variable is required")
	}

	model, err := gemini.NewModel(ctx, "gemini-2.5-flash", &genai.ClientConfig{
		APIKey: apiKey,
	})
	if err != nil {
		return nil, fmt.Errorf("creating gemini model: %w", err)
	}

	// Connect to the existing mark3labs MCP server as a client
	mcpURL := fmt.Sprintf("http://localhost%s/mcp", mcpAddr)
	transport := &gomcp.StreamableClientTransport{
		Endpoint: mcpURL,
	}

	mcpTools, err := mcptoolset.New(mcptoolset.Config{
		Transport: transport,
	})
	if err != nil {
		return nil, fmt.Errorf("creating MCP toolset from %s: %w", mcpURL, err)
	}

	a, err := llmagent.New(llmagent.Config{
		Name:        "recipe_assistant",
		Model:       model,
		Description: "A helpful recipe assistant",
		Instruction: `You are a friendly recipe assistant for "The Bluer Book" recipe collection.
You can search for recipes, get recipe details, create new recipes, update existing ones, and archive them.
When users ask about recipes, use your tools to find real data — don't make up recipes.
Keep responses concise and conversational. Format recipe names in bold.
If a tool returns multiple recipes, summarise them briefly rather than dumping all details.
When creating or updating recipes, confirm the details with the user before proceeding.`,
		Toolsets: []tool.Toolset{mcpTools},
	})
	if err != nil {
		return nil, fmt.Errorf("creating agent: %w", err)
	}

	sessionService := session.InMemoryService()

	r, err := runner.New(runner.Config{
		AppName:        "bluer_book_chat",
		Agent:          a,
		SessionService: sessionService,
	})
	if err != nil {
		return nil, fmt.Errorf("creating runner: %w", err)
	}

	return &Handler{
		runner:         r,
		sessionService: sessionService,
		logger:         log,
	}, nil
}

func (h *Handler) HandleChat(w http.ResponseWriter, r *http.Request) {
	var req chatRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid request body"}`, http.StatusBadRequest)
		return
	}
	if req.Message == "" {
		http.Error(w, `{"error":"message is required"}`, http.StatusBadRequest)
		return
	}

	ctx := r.Context()
	userID := "default_user"

	// Create or reuse session
	sessionID := req.SessionID
	if sessionID == "" {
		h.mu.Lock()
		resp, err := h.sessionService.Create(ctx, &session.CreateRequest{
			AppName: "bluer_book_chat",
			UserID:  userID,
		})
		h.mu.Unlock()
		if err != nil {
			h.logger.Error().Err(err).Msg("Failed to create session")
			http.Error(w, `{"error":"failed to create session"}`, http.StatusInternalServerError)
			return
		}
		sessionID = resp.Session.ID()
	}

	// Set SSE headers
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("X-Accel-Buffering", "no")

	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, `{"error":"streaming not supported"}`, http.StatusInternalServerError)
		return
	}

	userMsg := genai.NewContentFromText(req.Message, genai.RoleUser)

	for event, err := range h.runner.Run(ctx, userID, sessionID, userMsg, agent.RunConfig{
		StreamingMode: agent.StreamingModeSSE,
	}) {
		if err != nil {
			h.logger.Error().Err(err).Msg("Agent run error")
			writeSSE(w, flusher, chatEvent{Content: "Sorry, something went wrong.", Done: true, SessionID: sessionID})
			return
		}

		if event.Content != nil {
			for _, part := range event.Content.Parts {
				if part.Text != "" {
					writeSSE(w, flusher, chatEvent{
						Content:   part.Text,
						Done:      event.IsFinalResponse(),
						SessionID: sessionID,
					})
				}
			}
		}
	}

	// Send final done event
	writeSSE(w, flusher, chatEvent{Done: true, SessionID: sessionID})
}

func writeSSE(w http.ResponseWriter, flusher http.Flusher, event chatEvent) {
	data, err := json.Marshal(event)
	if err != nil {
		return
	}
	fmt.Fprintf(w, "data: %s\n\n", data)
	flusher.Flush()
}

// NewHandlerWithRetry attempts to create the chat handler with retries,
// allowing time for the MCP server to start.
func NewHandlerWithRetry(mcpAddr string, log logger.Logger, maxRetries int, delay time.Duration) (*Handler, error) {
	var lastErr error
	for i := 0; i < maxRetries; i++ {
		handler, err := NewHandler(mcpAddr, log)
		if err == nil {
			return handler, nil
		}
		lastErr = err
		log.Info().Int("attempt", i+1).Err(err).Msg("Chat handler init failed, retrying...")
		time.Sleep(delay)
	}
	return nil, fmt.Errorf("failed to create chat handler after %d attempts: %w", maxRetries, lastErr)
}
