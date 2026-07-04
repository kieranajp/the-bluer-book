package auth

import (
	"context"
	"net/http"

	"github.com/google/uuid"

	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
)

// HomeHeaderRoundTripper copies the home id from the request's context
// into an X-Home header. It's the client-side half of the loopback MCP
// bridge: the chat handler embeds it in the MCP transport's HTTPClient
// so tool calls carry the authenticated home across the boundary, where
// it's read back by InjectHomeFromHeader on the server side.
type HomeHeaderRoundTripper struct {
	Base http.RoundTripper
}

func (rt *HomeHeaderRoundTripper) RoundTrip(req *http.Request) (*http.Response, error) {
	if id, ok := HomeID(req.Context()); ok {
		req = req.Clone(req.Context())
		req.Header.Set(HeaderHome, id.String())
	}
	base := rt.Base
	if base == nil {
		base = http.DefaultTransport
	}
	return base.RoundTrip(req)
}

// InjectHomeFromHeader reads X-Home off an incoming HTTP request and
// stashes the parsed UUID on the returned context. Intended as the
// callback for mark3labs/mcp-go's WithHTTPContextFunc on the MCP
// server. Malformed headers are logged and dropped; the policy on the
// repo side will then deny all rows, which is the fail-closed default
// we want for an unknown caller. The MCP listener must bind to
// localhost — this function trusts whatever X-Home arrives.
func InjectHomeFromHeader(log logger.Logger) func(ctx context.Context, r *http.Request) context.Context {
	return func(ctx context.Context, r *http.Request) context.Context {
		h := r.Header.Get(HeaderHome)
		if h == "" {
			return ctx
		}
		id, err := uuid.Parse(h)
		if err != nil {
			log.Warn().Str("x_home", h).Msg("MCP: ignoring malformed X-Home")
			return ctx
		}
		return WithHome(ctx, id)
	}
}
