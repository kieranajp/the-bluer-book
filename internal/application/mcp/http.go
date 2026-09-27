package mcp

import (
	"context"
	"net/http"

	"github.com/google/uuid"
	"github.com/mark3labs/mcp-go/server"

	"github.com/kieranajp/the-bluer-book/internal/infrastructure/auth"
)

// NewPinnedHTTPServer serves s over streamable HTTP with every call acting on
// home, since no MCP call carries a caller to resolve one from.
func NewPinnedHTTPServer(s *server.MCPServer, home uuid.UUID) *server.StreamableHTTPServer {
	return server.NewStreamableHTTPServer(s,
		server.WithHTTPContextFunc(func(ctx context.Context, _ *http.Request) context.Context {
			return auth.WithHome(ctx, home)
		}),
	)
}
