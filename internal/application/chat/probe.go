package chat

import "time"

// Probe provides domain-oriented observability for chat sessions.
type Probe interface {
	SessionCreated(sessionID string)
	MessageReceived(sessionID string)
	ResponseCompleted(sessionID string, duration time.Duration, streamParts int)
	ChatError(err error)
}
