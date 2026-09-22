package main

import (
	"os"

	fetchimages "github.com/kieranajp/the-bluer-book/cmd/fetchimages"
	"github.com/kieranajp/the-bluer-book/cmd/migrate"
	"github.com/kieranajp/the-bluer-book/cmd/proposemerges"
	"github.com/kieranajp/the-bluer-book/cmd/server"
	"github.com/kieranajp/the-bluer-book/cmd/tag"
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
		},
		Commands: []*cli.Command{
			server.Command,
			migrate.Command,
			tag.Command,
			fetchimages.Command,
			// Dev-only. Unlike tag-recipes it is deliberately absent from the
			// Helm initContainer chain — it proposes destructive, one-way
			// ingredient merges that a human reviews before they reach a
			// migration.
			proposemerges.Command,
		},
	}

	if err := app.Run(os.Args); err != nil {
		log.Error().Err(err).Msg("application failed")
		os.Exit(1)
	}
}
