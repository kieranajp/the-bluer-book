package config

import (
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

	// Owner-role credentials. The `migrate` command uses these to apply
	// DDL; in dev they also back the server when APP_DB_USER is unset.
	DBUser string
	DBPass string

	// Application-role credentials. The server uses these so it connects
	// as a non-owner role that FORCE ROW LEVEL SECURITY actually applies
	// to. Falls back to the owner credentials when unset (single-role dev).
	AppDBUser string
	AppDBPass string

	DBName string
	DBHost string
	DBPort string

	GoogleAPIKey string
	GeminiModel  string
}

// New builds a Config from the CLI context.
func New(c *cli.Context) Config {
	return Config{
		ListenAddr:   c.String("listen-addr"),
		MCPAddr:      c.String("mcp-addr"),
		DBUser:       c.String("db-user"),
		DBPass:       c.String("db-pass"),
		AppDBUser:    c.String("app-db-user"),
		AppDBPass:    c.String("app-db-pass"),
		DBName:       c.String("db-name"),
		DBHost:       c.String("db-host"),
		DBPort:       c.String("db-port"),
		GoogleAPIKey: c.String("google-api-key"),
		GeminiModel:  c.String("gemini-model"),
	}
}

// DBDSN returns the Postgres connection string for the owner role
// (used by migrations).
func (c Config) DBDSN() string {
	return c.dsnFor(c.DBUser, c.DBPass)
}

// AppDBDSN returns the Postgres connection string for the application
// role. Falls back to the owner role if APP_DB_USER/APP_DB_PASS are
// unset — useful in dev, dangerous in prod (RLS would not apply).
func (c Config) AppDBDSN() string {
	user := c.AppDBUser
	pass := c.AppDBPass
	if user == "" {
		user = c.DBUser
		pass = c.DBPass
	}
	return c.dsnFor(user, pass)
}

func (c Config) dsnFor(user, pass string) string {
	return fmt.Sprintf(
		"postgres://%s:%s@%s:%s/%s?sslmode=disable",
		url.QueryEscape(user), url.QueryEscape(pass), c.DBHost, c.DBPort, c.DBName,
	)
}
