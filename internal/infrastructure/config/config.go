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

	DBUser string
	DBPass string
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
		DBName:       c.String("db-name"),
		DBHost:       c.String("db-host"),
		DBPort:       c.String("db-port"),
		GoogleAPIKey: c.String("google-api-key"),
		GeminiModel:  c.String("gemini-model"),
	}
}

// DBDSN returns the Postgres connection string.
func (c Config) DBDSN() string {
	return fmt.Sprintf(
		"postgres://%s:%s@%s:%s/%s?sslmode=disable",
		url.QueryEscape(c.DBUser), url.QueryEscape(c.DBPass), c.DBHost, c.DBPort, c.DBName,
	)
}
