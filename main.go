package main

import (
	"os"

	"github.com/kieranajp/the-bluer-book/cmd"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
	"github.com/urfave/cli/v2"
)

var (
	log logger.Logger
)

func setup(c *cli.Context) error {
	log = logger.New(c.String("log-level"))
	return nil
}

func main() {
	importer := cmd.NewImport()
	// server := cmd.NewServer()

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
				Name:  importer.Name(),
				Usage: importer.Usage(),
				Flags: importer.Flags(),
				Action: func(c *cli.Context) error {
					if err := setup(c); err != nil {
						return err
					}
					return importer.
						WithLogger(log).
						Run(c)
				},
			},
		},
	}

	if err := app.Run(os.Args); err != nil {
		log.Error().Err(err).Msg("application failed")
		os.Exit(1)
	}
}
