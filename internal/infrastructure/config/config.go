package config

import (
	"errors"
	"fmt"
	"net/url"

	"github.com/urfave/cli/v2"
)

// Config is the single place env-backed settings are gathered, so nothing
// downstream needs to reach for os.Getenv.
type Config struct {
	ListenAddr string
	MCPAddr    string

	DBUser string
	DBPass string
	DBName string
	DBHost string
	DBPort string

	// AppDBUser and AppDBPass are the non-owner role the server connects as;
	// DB_USER owns every table, so FORCE ROW LEVEL SECURITY does not bind it.
	AppDBUser string
	AppDBPass string

	GoogleAPIKey string
	GeminiModel  string

	// FounderSubject is the token subject whose first login attaches to the
	// founder home; empty leaves that home unclaimed.
	FounderSubject string

	// MCPHomeID is the home every MCP tool call acts on: the MCP server has no
	// caller to resolve, so it and the chat assistant serve one fixed home.
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

// DBDSN returns the connection string for the owning role, used by migrations
// and sweep commands that act on every home at once.
func (c Config) DBDSN() string {
	return c.dsn(c.DBUser, c.DBPass)
}

// ErrNoAppDBUser means APP_DB_USER is unset, so there is no non-owner role to
// connect as.
var ErrNoAppDBUser = errors.New("config: APP_DB_USER is not set")

// AppDBDSN has no fallback to DB_USER: that role bypasses row-level
// security, so a fallback would look correct while enforcing nothing.
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
