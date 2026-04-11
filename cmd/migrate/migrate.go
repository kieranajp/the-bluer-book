package migrate

import (
	"database/sql"
	"fmt"

	_ "github.com/lib/pq"
	"github.com/pressly/goose/v3"
	"github.com/urfave/cli/v2"

	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
	"github.com/kieranajp/the-bluer-book/migrations"
)

var Command = &cli.Command{
	Name:  "migrate",
	Usage: "Run database migrations",
	Flags: []cli.Flag{
		&cli.StringFlag{
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
	},
	Action: run,
}

func run(c *cli.Context) error {
	log := logger.New(logger.LogLevelInfo)

	dsn := fmt.Sprintf("postgres://%s:%s@%s:%s/%s?sslmode=disable",
		c.String("db-user"),
		c.String("db-pass"),
		c.String("db-host"),
		c.String("db-port"),
		c.String("db-name"),
	)

	db, err := sql.Open("postgres", dsn)
	if err != nil {
		return fmt.Errorf("failed to open database: %w", err)
	}
	defer db.Close()

	if err := db.Ping(); err != nil {
		return fmt.Errorf("failed to connect to database: %w", err)
	}

	log.Info().Msg("Running database migrations...")

	goose.SetBaseFS(migrations.FS)

	if err := goose.SetDialect("postgres"); err != nil {
		return fmt.Errorf("failed to set dialect: %w", err)
	}

	if err := goose.Up(db, "."); err != nil {
		return fmt.Errorf("failed to run migrations: %w", err)
	}

	log.Info().Msg("Migrations completed successfully")
	return nil
}
