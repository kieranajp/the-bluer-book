package migrate

import (
	"database/sql"
	"fmt"

	"github.com/lib/pq"
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
		&cli.StringFlag{
			Name:    "app-db-user",
			Usage:   "Non-owner database role the server connects as; its password is set from APP_DB_PASS after migrating",
			EnvVars: []string{"APP_DB_USER"},
			Value:   "bluer_book_app",
		},
		&cli.StringFlag{
			Name:    "app-db-pass",
			Usage:   "Password to set on APP_DB_USER",
			EnvVars: []string{"APP_DB_PASS"},
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

	// Seed goose's version table for databases that pre-date goose adoption.
	// If the schema already exists but goose has never run, mark the original
	// migrations as applied so they aren't re-executed.
	if err := seedExistingMigrations(db, log); err != nil {
		return fmt.Errorf("failed to seed migration history: %w", err)
	}

	if err := goose.Up(db, "."); err != nil {
		return fmt.Errorf("failed to run migrations: %w", err)
	}

	if err := setAppRolePassword(db, c.String("app-db-user"), c.String("app-db-pass"), log); err != nil {
		return err
	}

	log.Info().Msg("Migrations completed successfully")
	return nil
}

// setAppRolePassword gives the server's role the password the server will use.
// The migration creates the role without one, so the secret never lands in a
// file that ships inside the image; this runs as the owner, which is the only
// connection that could set it.
//
// ALTER ROLE takes no bind parameters, so both halves are quoted into the
// statement. A role that does not exist is an error worth failing the deploy
// for: the server would come up unable to connect and there would be nothing in
// the migration log saying why.
func setAppRolePassword(db *sql.DB, role, password string, log logger.Logger) error {
	if password == "" {
		log.Warn().Str("role", role).Msg("APP_DB_PASS not set — leaving the application role's password alone")
		return nil
	}
	if role == "" {
		return fmt.Errorf("APP_DB_PASS is set but APP_DB_USER is empty")
	}

	stmt := fmt.Sprintf("ALTER ROLE %s WITH PASSWORD %s", pq.QuoteIdentifier(role), pq.QuoteLiteral(password))
	if _, err := db.Exec(stmt); err != nil {
		return fmt.Errorf("failed to set the password for role %s: %w", role, err)
	}

	log.Info().Str("role", role).Msg("Set the application role's password")
	return nil
}

// seedExistingMigrations detects databases that were set up before goose was
// adopted and marks the pre-existing migrations as already applied. It checks
// whether the schema exists (recipes table) but goose hasn't tracked anything
// yet, then inserts version rows with ON CONFLICT DO NOTHING so it's safe to
// run repeatedly.
func seedExistingMigrations(db *sql.DB, log logger.Logger) error {
	// Check if this is a pre-goose database: schema exists but no goose table.
	var hasRecipes bool
	err := db.QueryRow(`SELECT EXISTS (
		SELECT 1 FROM information_schema.tables
		WHERE table_schema = 'public' AND table_name = 'recipes'
	)`).Scan(&hasRecipes)
	if err != nil {
		return err
	}
	if !hasRecipes {
		return nil // fresh database, nothing to seed
	}

	var hasGooseTable bool
	err = db.QueryRow(`SELECT EXISTS (
		SELECT 1 FROM information_schema.tables
		WHERE table_schema = 'public' AND table_name = 'goose_db_version'
	)`).Scan(&hasGooseTable)
	if err != nil {
		return err
	}
	if hasGooseTable {
		return nil // goose already tracking, nothing to do
	}

	log.Info().Msg("Detected pre-goose database, seeding migration history...")

	// Create goose's version table and mark all original migrations as applied.
	_, err = db.Exec(`
		CREATE TABLE IF NOT EXISTS goose_db_version (
			id SERIAL PRIMARY KEY,
			version_id BIGINT NOT NULL,
			is_applied BOOLEAN NOT NULL,
			tstamp TIMESTAMP DEFAULT now()
		);
		INSERT INTO goose_db_version (version_id, is_applied) VALUES
			(0, true),
			(1, true),
			(2, true),
			(3, true),
			(4, true),
			(5, true),
			(6, true)
		ON CONFLICT DO NOTHING;
	`)
	return err
}
