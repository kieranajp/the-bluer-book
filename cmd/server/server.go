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
	"github.com/kieranajp/the-bluer-book/internal/application/compliance"
	"github.com/kieranajp/the-bluer-book/internal/application/identity"
	"github.com/kieranajp/the-bluer-book/internal/application/mcp"
	"github.com/kieranajp/the-bluer-book/internal/domain/account"
	accountservice "github.com/kieranajp/the-bluer-book/internal/domain/account/service"
	pantryservice "github.com/kieranajp/the-bluer-book/internal/domain/pantry/service"
	"github.com/kieranajp/the-bluer-book/internal/domain/recipe/service"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/ai"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/auth"
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
				Usage:   "MCP server listen address (default 127.0.0.1:8082 — must not be publicly reachable; tenant scoping uses an internal X-Home header)",
				EnvVars: []string{"MCP_ADDR"},
				Value:   "127.0.0.1:8082",
			},
			&cli.StringFlag{
				Name:    "db-user",
				Usage:   "Owner DB role (only used as fallback when app-db-user is unset)",
				EnvVars: []string{"DB_USER"},
			},
			&cli.StringFlag{
				Name:    "db-pass",
				Usage:   "Owner DB password",
				EnvVars: []string{"DB_PASS"},
			},
			&cli.StringFlag{
				Name:    "app-db-user",
				Usage:   "Non-owner DB role for the server (RLS subject)",
				EnvVars: []string{"APP_DB_USER"},
			},
			&cli.StringFlag{
				Name:    "app-db-pass",
				Usage:   "Non-owner DB password",
				EnvVars: []string{"APP_DB_PASS"},
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
			&cli.StringFlag{
				Name:    "founder-subject",
				Usage:   "Kratos identity id that should be linked to the founder home on first login",
				EnvVars: []string{"FOUNDER_SUBJECT"},
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

	// Set up database. The server connects as the non-owner app role so
	// FORCE ROW LEVEL SECURITY applies; the owner role is only used by
	// `migrate` and by the compliance flow's destructive deletes
	// (PurgeHome / DeleteUser).
	sqlDB, err := sql.Open("postgres", cfg.AppDBDSN())
	if err != nil {
		return fmt.Errorf("failed to open database: %w", err)
	}
	defer sqlDB.Close()
	if err := sqlDB.Ping(); err != nil {
		return fmt.Errorf("failed to ping app-role database: %w", err)
	}

	// Owner-role pool, used only by the compliance flow. Falls back to
	// the app-role DSN when the owner credentials aren't configured —
	// fine in single-role dev, but in prod APP_DB_* and DB_* must point
	// at different roles for FORCE RLS to actually apply.
	ownerDB, err := sql.Open("postgres", cfg.DBDSN())
	if err != nil {
		return fmt.Errorf("failed to open owner database: %w", err)
	}
	defer ownerDB.Close()
	if err := ownerDB.Ping(); err != nil {
		return fmt.Errorf("failed to ping owner database: %w", err)
	}

	// Expose connection-pool stats (go_sql_*) alongside the per-query metrics
	// recorded by the instrumented DBTX below.
	metrics.RegisterDBStats(sqlDB)

	// Pool-level queries wrapped in the instrumented DBTX — picks up
	// account-resolution + pantry pool reads. Recipe queries run inside a
	// per-request transaction (see repository.InHomeTx) so they don't go
	// through this wrapper; they show up in go_sql_* pool stats instead.
	queries := db.New(metrics.NewInstrumentedDBTX(sqlDB))

	// Recipe + pantry repos own their own *sql.DB to open per-request
	// transactions inside InHomeTx, which sets the app.home_id GUC that
	// RLS reads.
	repo := repository.NewRecipeRepository(sqlDB, log)
	pantryRepo := repository.NewPantryRepository(sqlDB, log)

	// Account/identity queries run on the pool — these tables are not
	// under RLS (they're the resolution layer that runs *before* the home
	// GUC is set). The service wraps the repo and owns provisioning logic.
	accountRepo := repository.NewAccountRepository(queries)
	accountSvc := accountservice.New(accountRepo, accountservice.Config{
		FounderSubject: cfg.FounderSubject,
	}, nil)
	userResolver := identity.NewResolver(accountSvc)
	accountHandler := api.NewAccountHandler(accountSvc, log)

	// Create probes
	recipeProbe := metrics.NewRecipeProbe(log)
	pantryProbe := metrics.NewPantryProbe(log)
	chatProbe := metrics.NewChatProbe(log)

	// Initialize services
	recipeService := service.NewRecipeService(repo, recipeProbe)
	pantryService := pantryservice.NewPantryService(pantryRepo, pantryProbe)

	// Compliance (Google Play account-delete + data-export) is an
	// application-layer orchestration: it crosses domains, so it lives
	// outside any one of them. The admin repo runs on the owner pool so
	// PurgeHome / DeleteUser bypass FORCE RLS. IdentityDeleter is a
	// no-op until Phase 0 wires a real Kratos admin caller.
	adminRepo := repository.NewAccountAdminRepository(ownerDB)
	complianceSvc := compliance.New(compliance.Deps{
		Account:  accountRepo,
		Admin:    adminRepo,
		Identity: account.NoopIdentityDeleter{},
		Recipes:  recipeService,
		Pantry:   pantryService,
		Log:      log,
	}, nil)
	complianceHandler := api.NewComplianceHandler(complianceSvc, log)
	accountDeleteWeb := api.NewAccountDeleteWebHandler(complianceSvc, log)

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
	// The MCP listener trusts X-Home from its incoming requests — only
	// safe because mcpAddr defaults to 127.0.0.1, so cross-tenant traffic
	// cannot reach this port. The chat handler (in-process) sends X-Home
	// derived from the caller's authenticated home; tool handlers read it
	// back out of ctx via auth.HomeID inside InHomeTx.
	httpMCPServer := server.NewStreamableHTTPServer(mcpServer,
		server.WithHTTPContextFunc(auth.InjectHomeFromHeader(log)),
	)
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
		photoHandler = api.NewPhotoHandler(r2, sqlDB, log)
		log.Info().Msg("R2 photo upload enabled")
	} else {
		log.Warn().Msg("R2 not configured — photo upload endpoint disabled")
	}

	// Create API router
	router := api.NewRouter(recipeService, pantryService, accountHandler, complianceHandler, accountDeleteWeb, chatHandler, photoHandler, scanner, userResolver, log)

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
