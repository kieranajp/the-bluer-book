package importer

import (
	"database/sql"
	"fmt"
	"net/http"
	"time"

	_ "github.com/lib/pq"

	"github.com/kieranajp/the-bluer-book/internal/application"
	"github.com/kieranajp/the-bluer-book/internal/domain/recipe/service"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/llm"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/storage/db"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/storage/repository"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/trello"
	"github.com/urfave/cli/v2"
)

var (
	Name  = "import"
	Usage = "Import recipes to the database"
	Flags = []cli.Flag{
		&cli.StringFlag{
			Name:     "trello-path",
			Aliases:  []string{"t"},
			Required: true,
			Usage:    "Path to the Trello file",
		},
		&cli.StringFlag{
			Name:     "gemini-api-key",
			Required: true,
			Usage:    "Gemini API key",
			EnvVars:  []string{"GEMINI_API_KEY"},
		},
	}
)

func Run(c *cli.Context) error {
	// Initialise logger
	log := logger.New(logger.LogLevelInfo)

	// Set up database
	sqlDB, err := sql.Open("postgres", c.String("db-dsn"))
	if err != nil {
		return fmt.Errorf("failed to open database: %w", err)
	}
	defer sqlDB.Close()

	queries := db.New(sqlDB)
	repo := repository.NewRecipeRepository(queries)

	// Initialise LLM client
	httpClient := &http.Client{Timeout: 30 * time.Second}
	llmClient := llm.NewGeminiClient(c.String("gemini-api-key"), log, httpClient)

	// Initialise service layer
	loader := trello.NewTrelloLoader(log, c.String("trello-path"))
	normaliser := service.NewNormalisationService(llmClient, log, repo)

	// Initialise handler
	handler := application.NewImportHandler(loader, normaliser, repo, log)

	// Run import
	return handler.RunImport(c.Context)
}
