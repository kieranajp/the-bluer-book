package cmd

import (
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
	"github.com/urfave/cli/v2"
)

type App struct {
	log logger.Logger
}

func NewApp(log logger.Logger) *App {
	return &App{log: log}
}

// Command defines the interface that all commands must implement
type Command interface {
	// Name returns the name of the command
	Name() string

	// Usage returns the usage description of the command
	Usage() string

	// Flags returns the command's flags
	Flags() []cli.Flag

	// WithApp returns a new command with the given app
	WithApp(*App) Command

	// Run executes the command with the given context
	Run(*cli.Context) error
}
