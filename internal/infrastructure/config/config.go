package config

import (
	"errors"
	"fmt"
	"net/url"

	"github.com/urfave/cli/v2"
)

// Config holds all runtime configuration, sourced from CLI flags (which in turn
// read their EnvVars). It's the single place env-backed settings are gathered,
// so nothing downstream needs to reach for os.Getenv.
type Config struct {
	ListenAddr string
	MCPAddr    string

	DBUser string
	DBPass string
	DBName string
	DBHost string
	DBPort string

	// AppDBUser and AppDBPass are the non-owner role the server connects as.
	// FORCE ROW LEVEL SECURITY does not bind a superuser or a table owner, and
	// DB_USER is both, so connecting as it would leave every policy inert while
	// everything still appeared to work.
	AppDBUser string
	AppDBPass string

	GoogleAPIKey string
	GeminiModel  string

	// FounderSubject is the token subject whose first login attaches to the
	// founder home rather than to a fresh one. Empty means nobody gets that
	// treatment, and the founder home stays unclaimed.
	FounderSubject string

	// MCPHomeID is the home every MCP tool call acts on. The MCP server has no
	// caller to resolve, so it serves one fixed home and the chat assistant
	// reaches the same one through it.
	MCPHomeID string
}

// New builds a Config from the CLI context.
func New(c *cli.Context) Config {
	return Config{
		ListenAddr:   c.String("listen-addr"),
		MCPAddr:      c.String("mcp-addr"),
		DBUser:       c.String("db-user"),
		DBPass:       c.String("db-pass"),
		DBName:       c.String("db-name"),
		DBHost:       c.String("db-host"),
		DBPort:       c.String("db-port"),
		AppDBUser:    c.String("app-db-user"),
		AppDBPass:    c.String("app-db-pass"),
		GoogleAPIKey: c.String("google-api-key"),
		GeminiModel:  c.String("gemini-model"),

		FounderSubject: c.String("founder-subject"),
		MCPHomeID:      c.String("mcp-home-id"),
	}
}

// DBDSN returns the Postgres connection string for the owning role. Migrations
// and the sweep commands use it: they act on every home at once, which no
// policy-bound role can do.
func (c Config) DBDSN() string {
	return c.dsn(c.DBUser, c.DBPass)
}

// ErrNoAppDBUser means APP_DB_USER is unset, so there is no non-owner role to
// connect as.
var ErrNoAppDBUser = errors.New("config: APP_DB_USER is not set")

// AppDBDSN returns the connection string for the role the request path uses.
// It has no fallback to DB_USER on purpose. The owner bypasses every isolation
// policy in the schema, so a fallback would answer every request correctly
// while enforcing nothing, and there is no symptom to notice.
func (c Config) AppDBDSN() (string, error) {
	if c.AppDBUser == "" {
		return "", ErrNoAppDBUser
	}
	return c.dsn(c.AppDBUser, c.AppDBPass), nil
}

func (c Config) dsn(user, pass string) string {
	return fmt.Sprintf(
		"postgres://%s:%s@%s:%s/%s?sslmode=disable",
		url.QueryEscape(user), url.QueryEscape(pass), c.DBHost, c.DBPort, c.DBName,
	)
}
