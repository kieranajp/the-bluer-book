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
	"github.com/urfave/cli/v2"

	"github.com/kieranajp/the-bluer-book/internal/application/api"
	"github.com/kieranajp/the-bluer-book/internal/domain/recipe/service"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/llm"
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
				Name:     "gemini-api-key",
				Required: true,
				Usage:    "Gemini API key",
				EnvVars:  []string{"GEMINI_API_KEY"},
			},
		},
		Action: run,
	}
)

func run(c *cli.Context) error {
	// Get configuration values
	dbDSN := c.String("db-dsn")
	listenAddr := c.String("listen-addr")
	geminiAPIKey := c.String("gemini-api-key")

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

	// Initialize LLM client
	httpClient := &http.Client{Timeout: 30 * time.Second}
	llmClient := llm.NewGeminiClient(geminiAPIKey, log, httpClient)

	// Initialize services
	normalizer := service.NewNormalisationService(llmClient, log, repo)
	importService := service.NewImportService(normalizer, repo, log)

	// Create API router
	router := api.NewRouter(importService, log)

	// Create HTTP server
	server := &http.Server{
		Addr:    listenAddr,
		Handler: router,
	}

	// Start server in a goroutine
	go func() {
		log.Info().Str("address", listenAddr).Msg("Starting HTTP server")
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Error().Err(err).Msg("Failed to start server")
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

	if err := server.Shutdown(ctx); err != nil {
		log.Error().Err(err).Msg("Server forced to shutdown")
		return err
	}

	log.Info().Msg("Server exited")
	return nil
}
