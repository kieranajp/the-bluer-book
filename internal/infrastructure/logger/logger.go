package logger

import (
	"os"
	"strings"

	"github.com/rs/zerolog"
)

type Logger interface {
	Info() *zerolog.Event
	Debug() *zerolog.Event
	Error() *zerolog.Event
}

type zerologLogger struct {
	logger zerolog.Logger
}

func parseLevel(level string) zerolog.Level {
	switch strings.ToLower(level) {
	case "debug":
		return zerolog.DebugLevel
	case "info":
		return zerolog.InfoLevel
	case "warn":
		return zerolog.WarnLevel
	case "error":
		return zerolog.ErrorLevel
	default:
		return zerolog.InfoLevel
	}
}

func New(level string) Logger {
	output := zerolog.ConsoleWriter{Out: os.Stdout, TimeFormat: "2006-01-02 15:04:05"}
	logger := zerolog.New(output).With().Timestamp().Caller().Logger().Level(parseLevel(level))
	return &zerologLogger{logger: logger}
}

func (l *zerologLogger) Info() *zerolog.Event {
	return l.logger.Info()
}

func (l *zerologLogger) Debug() *zerolog.Event {
	return l.logger.Debug()
}

func (l *zerologLogger) Error() *zerolog.Event {
	return l.logger.Error()
}
