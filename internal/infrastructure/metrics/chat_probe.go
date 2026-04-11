package metrics

import (
	"time"

	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

var (
	chatSessions = promauto.NewCounter(prometheus.CounterOpts{
		Name: "bluerbook_chat_sessions_created_total",
		Help: "Total chat sessions created.",
	})

	chatMessages = promauto.NewCounter(prometheus.CounterOpts{
		Name: "bluerbook_chat_messages_total",
		Help: "Total chat messages received.",
	})

	chatResponseDuration = promauto.NewHistogram(prometheus.HistogramOpts{
		Name:    "bluerbook_chat_response_duration_seconds",
		Help:    "Chat response duration in seconds.",
		Buckets: []float64{0.5, 1, 2, 5, 10, 20, 30, 60},
	})

	chatStreamParts = promauto.NewHistogram(prometheus.HistogramOpts{
		Name:    "bluerbook_chat_response_stream_parts",
		Help:    "Number of stream parts per chat response.",
		Buckets: []float64{1, 2, 5, 10, 20, 50, 100},
	})

	chatErrors = promauto.NewCounter(prometheus.CounterOpts{
		Name: "bluerbook_chat_errors_total",
		Help: "Total chat errors.",
	})
)

// ChatProbe implements chat.Probe with Prometheus metrics and structured logging.
type ChatProbe struct {
	logger logger.Logger
}

func NewChatProbe(log logger.Logger) *ChatProbe {
	return &ChatProbe{logger: log}
}

func (p *ChatProbe) SessionCreated(sessionID string) {
	chatSessions.Inc()
	p.logger.Info().Str("probe", "chat").Str("session_id", sessionID).Msg("chat session created")
}

func (p *ChatProbe) MessageReceived(sessionID string) {
	chatMessages.Inc()
	p.logger.Info().Str("probe", "chat").Str("session_id", sessionID).Msg("chat message received")
}

func (p *ChatProbe) ResponseCompleted(sessionID string, duration time.Duration, streamParts int) {
	chatResponseDuration.Observe(duration.Seconds())
	chatStreamParts.Observe(float64(streamParts))
	p.logger.Info().
		Str("probe", "chat").
		Str("session_id", sessionID).
		Dur("duration", duration).
		Int("stream_parts", streamParts).
		Msg("chat response completed")
}

func (p *ChatProbe) ChatError(err error) {
	chatErrors.Inc()
	p.logger.Error().Str("probe", "chat").Err(err).Msg("chat error")
}
