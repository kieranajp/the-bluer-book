package logger

import (
	"os"

	"github.com/rs/zerolog"
)

type Logger interface {
	Info() *zerolog.Event
	Debug() *zerolog.Event
	Warn() *zerolog.Event
	Error() *zerolog.Event
}

type LogLevel string

const (
	LogLevelDebug LogLevel = "debug"
	LogLevelInfo  LogLevel = "info"
	LogLevelWarn  LogLevel = "warn"
	LogLevelError LogLevel = "error"
)

type zerologLogger struct {
	logger zerolog.Logger
}

func parseLevel(level LogLevel) zerolog.Level {
	switch level {
	case LogLevelDebug:
		return zerolog.DebugLevel
	case LogLevelInfo:
		return zerolog.InfoLevel
	case LogLevelWarn:
		return zerolog.WarnLevel
	case LogLevelError:
		return zerolog.ErrorLevel
	default:
		return zerolog.InfoLevel
	}
}

func New(level LogLevel) Logger {
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

func (l *zerologLogger) Warn() *zerolog.Event {
	return l.logger.Warn()
}

func (l *zerologLogger) Error() *zerolog.Event {
	return l.logger.Error()
}
