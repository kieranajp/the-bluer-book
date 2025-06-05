package main

import (
	"os"

	"github.com/kieranajp/the-bluer-book/cmd/importer"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
	"github.com/urfave/cli/v2"
)

var (
	log logger.Logger
)

func main() {
	log = logger.New(logger.LogLevelInfo)

	app := &cli.App{
		Name:  "The Bluer Book",
		Usage: "Recipe book",
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:    "log-level",
				Usage:   "Log level (debug, info, warn, error)",
				EnvVars: []string{"LOG_LEVEL"},
				Value:   "info",
			},
			&cli.StringFlag{
				Name:    "db-dsn",
				Usage:   "Database DSN",
				EnvVars: []string{"DB_DSN"},
			},
		},
		Commands: []*cli.Command{
			{
				Name:   importer.Name,
				Usage:  importer.Usage,
				Flags:  importer.Flags,
				Action: importer.Run,
			},
		},
	}

	if err := app.Run(os.Args); err != nil {
		log.Error().Err(err).Msg("application failed")
		os.Exit(1)
	}
}
