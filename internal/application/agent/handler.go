package agent

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"

	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
	"google.golang.org/adk/agent"
	"google.golang.org/adk/runner"
	"google.golang.org/adk/session"
	"google.golang.org/genai"
)

type ChatHandler struct {
	runner         *runner.Runner
	sessionService session.Service
	appName        string
	logger         logger.Logger
}

func NewChatHandler(rootAgent agent.Agent, logger logger.Logger) (*ChatHandler, error) {
	sessionService := session.InMemoryService()
	appName := "the-bluer-book"

	r, err := runner.New(runner.Config{
		AppName:        appName,
		Agent:          rootAgent,
		SessionService: sessionService,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to create runner: %w", err)
	}

	return &ChatHandler{
		runner:         r,
		sessionService: sessionService,
		appName:        appName,
		logger:         logger,
	}, nil
}

type ChatRequest struct {
	Message   string `json:"message"`
	UserID    string `json:"userId,omitempty"`
	SessionID string `json:"sessionId,omitempty"`
}

func (h *ChatHandler) HandleChat(w http.ResponseWriter, r *http.Request) {
	var req ChatRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.logger.Error().Err(err).Msg("Failed to decode request")
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}

	userID := req.UserID
	if userID == "" {
		userID = "default-user"
	}

	sessionID := req.SessionID
	if sessionID == "" {
		sessionID = "default-session"
	}

	// Ensure session exists (create if needed)
	ctx := r.Context()
	_, err := h.sessionService.Get(ctx, &session.GetRequest{
		AppName:   h.appName,
		UserID:    userID,
		SessionID: sessionID,
	})
	if err != nil {
		// Session doesn't exist, create it
		_, err = h.sessionService.Create(ctx, &session.CreateRequest{
			AppName:   h.appName,
			UserID:    userID,
			SessionID: sessionID,
		})
		if err != nil {
			h.logger.Error().Err(err).Msg("Failed to create session")
			http.Error(w, "Failed to create session", http.StatusInternalServerError)
			return
		}
	}

	userMessage := &genai.Content{
		Role: "user",
		Parts: []*genai.Part{
			{Text: req.Message},
		},
	}

	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")

	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "Streaming not supported", http.StatusInternalServerError)
		return
	}

	h.logger.Info().Str("userID", userID).Str("sessionID", sessionID).Str("message", req.Message).Msg("🚀 [HANDLER] Starting agent run")

	runConfig := agent.RunConfig{
		StreamingMode: agent.StreamingModeSSE,
	}

	eventCount := 0
	for event, err := range h.runner.Run(ctx, userID, sessionID, userMessage, runConfig) {
		eventCount++

		if err != nil {
			h.logger.Error().Err(err).Msg("❌ [HANDLER] Error during agent run")
			fmt.Fprintf(w, "event: error\ndata: %s\n\n", err.Error())
			flusher.Flush()
			return
		}

		// Only stream content from final responses to avoid duplicates
		if event.Content != nil && event.IsFinalResponse() {
			for _, part := range event.Content.Parts {
				if part.Text != "" {
					h.logger.Info().
						Str("author", event.Author).
						Int("textLen", len(part.Text)).
						Msg("✉️ [HANDLER] Sending final text chunk to client")
					data := map[string]interface{}{
						"text":   part.Text,
						"author": event.Author,
					}
					jsonData, _ := json.Marshal(data)
					fmt.Fprintf(w, "data: %s\n\n", jsonData)
					flusher.Flush()
				}
			}
		}
	}

	h.logger.Info().Int("totalEvents", eventCount).Msg("✅ [HANDLER] Agent run completed")

	fmt.Fprintf(w, "event: done\ndata: {}\n\n")
	flusher.Flush()
}

func (h *ChatHandler) HandleChatNonStreaming(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req ChatRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.logger.Error().Err(err).Msg("Failed to decode request")
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}

	userID := req.UserID
	if userID == "" {
		userID = "default-user"
	}

	sessionID := req.SessionID
	if sessionID == "" {
		sessionID = "default-session"
	}

	userMessage := &genai.Content{
		Role: "user",
		Parts: []*genai.Part{
			{Text: req.Message},
		},
	}

	runConfig := agent.RunConfig{
		StreamingMode: agent.StreamingModeNone,
	}

	ctx := context.Background()
	var responseText string
	for event, err := range h.runner.Run(ctx, userID, sessionID, userMessage, runConfig) {
		if err != nil {
			h.logger.Error().Err(err).Msg("Error during agent run")
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		if event.Content != nil {
			for _, part := range event.Content.Parts {
				responseText += part.Text
			}
		}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"response": responseText,
	})
}
