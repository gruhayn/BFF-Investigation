package main

import (
	"flag"
	"log/slog"
	"os"

	"investigate_bff/config"
	"investigate_bff/internal/app"
	"investigate_bff/internal/logger"
)

func main() {
	profile := flag.String("profile", "default", "config profile")
	flag.Parse()

	cfg, err := config.Load(*profile)
	if err != nil {
		slog.Error("failed to load config", "error", err)
		os.Exit(1)
	}

	baseLogger := logger.New(cfg.LogLevel, cfg.ServiceName)
	slog.SetDefault(baseLogger)

	if err := app.Run(cfg, baseLogger); err != nil {
		slog.Error("app failed", "error", err)
		os.Exit(1)
	}
}
