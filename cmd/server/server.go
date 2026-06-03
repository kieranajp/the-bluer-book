package server

import (
	"context"
	"database/sql"
	"fmt"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	_ "github.com/lib/pq"
	"github.com/mark3labs/mcp-go/server"
	"github.com/urfave/cli/v2"

	"github.com/kieranajp/the-bluer-book/internal/application/api"
	"github.com/kieranajp/the-bluer-book/internal/application/chat"
	"github.com/kieranajp/the-bluer-book/internal/application/mcp"
	pantryservice "github.com/kieranajp/the-bluer-book/internal/domain/pantry/service"
	"github.com/kieranajp/the-bluer-book/internal/domain/recipe/service"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/ai"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/config"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/metrics"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/storage/db"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/storage/repository"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/upload"
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
			}, &cli.StringFlag{
				Name:    "db-user",
				Usage:   "Database Username",
				EnvVars: []string{"DB_USER"},
			},
			&cli.StringFlag{
				Name:    "db-pass",
				Usage:   "Database Password",
				EnvVars: []string{"DB_PASS"},
			},
			&cli.StringFlag{
				Name:    "db-name",
				Usage:   "Database Name",
				EnvVars: []string{"DB_NAME"},
			},
			&cli.StringFlag{
				Name:    "db-host",
				Usage:   "Database Host",
				EnvVars: []string{"DB_HOST"},
			},
			&cli.StringFlag{
				Name:    "db-port",
				Usage:   "Database Port",
				EnvVars: []string{"DB_PORT"},
			},
			&cli.StringFlag{
				Name:    "google-api-key",
				Usage:   "Google AI Studio API key",
				EnvVars: []string{"GOOGLE_API_KEY"},
			},
			&cli.StringFlag{
				Name:    "gemini-model",
				Usage:   "Gemini model used by the chat handler",
				EnvVars: []string{"GEMINI_MODEL"},
				Value:   "gemini-3.5-flash",
			},
			&cli.StringFlag{Name: "r2-account-id", EnvVars: []string{"R2_ACCOUNT_ID"}},
			&cli.StringFlag{Name: "r2-jurisdiction", EnvVars: []string{"R2_JURISDICTION"}},
			&cli.StringFlag{Name: "r2-access-key-id", EnvVars: []string{"R2_ACCESS_KEY_ID"}},
			&cli.StringFlag{Name: "r2-secret-access-key", EnvVars: []string{"R2_SECRET_ACCESS_KEY"}},
			&cli.StringFlag{Name: "r2-bucket", EnvVars: []string{"R2_BUCKET"}},
			&cli.StringFlag{Name: "r2-public-url", EnvVars: []string{"R2_PUBLIC_URL"}},
		},
		Action: run,
	}
)

func run(c *cli.Context) error {
	cfg := config.New(c)
	listenAddr := cfg.ListenAddr
	mcpAddr := cfg.MCPAddr

	// Initialize logger
	log := logger.New(logger.LogLevelInfo)

	// Set up database
	sqlDB, err := sql.Open("postgres", cfg.DBDSN())
	if err != nil {
		return fmt.Errorf("failed to open database: %w", err)
	}
	defer sqlDB.Close()

	// Test database connection
	if err := sqlDB.Ping(); err != nil {
		return fmt.Errorf("failed to ping database: %w", err)
	}

	// Expose connection-pool stats (go_sql_*) alongside the per-query metrics
	// recorded by the instrumented DBTX below.
	metrics.RegisterDBStats(sqlDB)

	// Initialize dependencies. Wrapping the pool in an instrumented DBTX times
	// every sqlc query without the repository needing to know about metrics.
	queries := db.New(metrics.NewInstrumentedDBTX(sqlDB))
	repo := repository.NewRecipeRepository(queries, sqlDB, log)
	pantryRepo := repository.NewPantryRepository(queries, log)

	// Create probes
	recipeProbe := metrics.NewRecipeProbe(log)
	pantryProbe := metrics.NewPantryProbe(log)
	chatProbe := metrics.NewChatProbe(log)

	// Initialize services
	recipeService := service.NewRecipeService(repo, recipeProbe)
	pantryService := pantryservice.NewPantryService(pantryRepo, pantryProbe)

	// Create MCP handler
	mcpHandler := mcp.NewRecipeMCPHandler(recipeService, log)

	// Create MCP server
	mcpServer := server.NewMCPServer("Recipe Management Server", "1.0.0",
		server.WithToolCapabilities(true),
	)
	mcpHandler.RegisterTools(mcpServer)

	// Start MCP server — bind the listener synchronously so it's ready before the chat handler connects
	mcpListener, err := net.Listen("tcp", mcpAddr)
	if err != nil {
		return fmt.Errorf("failed to listen on MCP address %s: %w", mcpAddr, err)
	}
	httpMCPServer := server.NewStreamableHTTPServer(mcpServer)
	go func() {
		log.Info().Str("address", mcpAddr).Msg("Starting MCP server")
		if err := http.Serve(mcpListener, httpMCPServer); err != nil && err != http.ErrServerClosed {
			log.Error().Err(err).Msg("MCP server failed")
			os.Exit(1)
		}
	}()

	// Create chat handler — MCP server is guaranteed to be listening
	chatHandler, err := chat.NewHandler(cfg, log, chatProbe)
	if err != nil {
		return fmt.Errorf("failed to create chat handler: %w", err)
	}

	// Create the shopping-list photo scanner (shares the chat handler's Gemini
	// key). Optional — without a key the scan endpoint reports unavailable.
	var scanner *ai.ShoppingListScanner
	if cfg.GoogleAPIKey != "" {
		scanner, err = ai.NewShoppingListScanner(context.Background(), cfg.GoogleAPIKey, cfg.GeminiModel, log)
		if err != nil {
			return fmt.Errorf("failed to create shopping list scanner: %w", err)
		}
		log.Info().Msg("Shopping list photo scanning enabled")
	} else {
		log.Warn().Msg("GOOGLE_API_KEY not set — shopping list photo scanning disabled")
	}

	// Create photo handler if R2 is configured
	var photoHandler *api.PhotoHandler
	if c.String("r2-account-id") != "" && c.String("r2-bucket") != "" {
		r2 := upload.NewR2Uploader(
			c.String("r2-account-id"),
			c.String("r2-jurisdiction"),
			c.String("r2-access-key-id"),
			c.String("r2-secret-access-key"),
			c.String("r2-bucket"),
			c.String("r2-public-url"),
			log,
		)
		photoHandler = api.NewPhotoHandler(r2, queries, sqlDB, log)
		log.Info().Msg("R2 photo upload enabled")
	} else {
		log.Warn().Msg("R2 not configured — photo upload endpoint disabled")
	}

	// Create API router
	router := api.NewRouter(recipeService, pantryService, scanner, chatHandler, photoHandler, log)

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
