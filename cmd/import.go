package cmd

import (
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
	"github.com/urfave/cli/v2"
)

type Import struct {
	log logger.Logger
}

func NewImport() *Import {
	return &Import{}
}

func (i *Import) Name() string {
	return "import"
}

func (i *Import) Usage() string {
	return "Import recipes to the database"
}

func (i *Import) Flags() []cli.Flag {
	return []cli.Flag{}
}

func (i *Import) Run(c *cli.Context) error {
	i.log.Info().Msg("Importing recipes to the database")
	return nil
}

func (i *Import) WithLogger(log logger.Logger) *Import {
	i.log = log
	return i
}
