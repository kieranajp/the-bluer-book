package server

import (
	"context"
	"database/sql"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	_ "github.com/lib/pq"
	"github.com/mark3labs/mcp-go/server"
	"github.com/urfave/cli/v2"

	"github.com/kieranajp/the-bluer-book/internal/application/api"
	"github.com/kieranajp/the-bluer-book/internal/application/mcp"
	"github.com/kieranajp/the-bluer-book/internal/domain/recipe/service"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/storage/db"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/storage/repository"
)

var (
	Command = &cli.Command{
		Name:  "server",
		Usage: "Start the HTTP API server",
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:    "listen-addr",
				Usage:   "Server listen address",
				EnvVars: []string{"LISTEN_ADDR"},
				Value:   ":8080",
			},
			&cli.StringFlag{
				Name:    "mcp-addr",
				Usage:   "MCP server listen address",
				EnvVars: []string{"MCP_ADDR"},
				Value:   ":8082",
			},
		},
		Action: run,
	}
)

func run(c *cli.Context) error {
	// Get configuration values
	dbDSN := c.String("db-dsn")
	listenAddr := c.String("listen-addr")
	mcpAddr := c.String("mcp-addr")

	// Initialize logger
	log := logger.New(logger.LogLevelInfo)

	// Set up database
	sqlDB, err := sql.Open("postgres", dbDSN)
	if err != nil {
		return fmt.Errorf("failed to open database: %w", err)
	}
	defer sqlDB.Close()

	// Test database connection
	if err := sqlDB.Ping(); err != nil {
		return fmt.Errorf("failed to ping database: %w", err)
	}

	// Initialize dependencies
	queries := db.New(sqlDB)
	repo := repository.NewRecipeRepository(queries, sqlDB, log)

	// Initialize services
	recipeService := service.NewRecipeService(repo)

	// Create MCP handler
	mcpHandler := mcp.NewRecipeMCPHandler(recipeService, log)

	// Create MCP server
	mcpServer := server.NewMCPServer("Recipe Management Server", "1.0.0",
		server.WithToolCapabilities(true),
	)
	mcpHandler.RegisterTools(mcpServer)

	// Create API router
	router := api.NewRouter(recipeService, log)

	// Create HTTP server
	httpServer := &http.Server{
		Addr:    listenAddr,
		Handler: router,
	}

	// Start HTTP server in a goroutine
	go func() {
		log.Info().Str("address", listenAddr).Msg("Starting HTTP server")
		if err := httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Error().Err(err).Msg("HTTP server failed")
			os.Exit(1)
		}
	}()

	// Start MCP server in a goroutine
	go func() {
		log.Info().Str("address", mcpAddr).Msg("Starting MCP server")
		httpMCPServer := server.NewStreamableHTTPServer(mcpServer)
		if err := httpMCPServer.Start(mcpAddr); err != nil {
			log.Error().Err(err).Msg("MCP server failed")
			os.Exit(1)
		}
	}()

	// Set up graceful shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Info().Msg("Shutting down server...")

	// Create a context with timeout for shutdown
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := httpServer.Shutdown(ctx); err != nil {
		log.Error().Err(err).Msg("Server forced to shutdown")
		return err
	}

	log.Info().Msg("Server exited")
	return nil
}
