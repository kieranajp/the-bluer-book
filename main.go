package main

import (
	"os"

	"github.com/kieranajp/the-bluer-book/cmd/server"
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
		},
	}

	if err := app.Run(os.Args); err != nil {
		log.Error().Err(err).Msg("application failed")
		os.Exit(1)
	}
}
