package logger

import (
	"log/slog"
	"os"
	"strings"
)

func New(level string, serviceName string) *slog.Logger {
	logLevel := new(slog.LevelVar)
	logLevel.Set(parseLevel(level))

	handler := slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: logLevel})
	return slog.New(handler).With("service", serviceName)
}

func parseLevel(level string) slog.Level {
	switch strings.ToUpper(level) {
	case "DEBUG":
		return slog.LevelDebug
	case "WARN":
		return slog.LevelWarn
	case "ERROR":
		return slog.LevelError
	default:
		return slog.LevelInfo
	}
}
