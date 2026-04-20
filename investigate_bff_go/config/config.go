package config

import (
	"fmt"
	"os"
	"strconv"
	"time"

	"github.com/joho/godotenv"
)

type Config struct {
	ServerPort   string
	LogLevel     string
	Profile      string
	ServiceName  string
	ReadTimeout  time.Duration
	WriteTimeout time.Duration
	IdleTimeout  time.Duration
}

func Load(profile string) (*Config, error) {
	if err := godotenv.Load(fmt.Sprintf("profiles/%s.env", profile)); err != nil {
		return nil, err
	}

	return &Config{
		ServerPort:   getEnv("SERVER_PORT", "8080"),
		LogLevel:     getEnv("LOG_LEVEL", "info"),
		Profile:      profile,
		ServiceName:  getEnv("SERVICE_NAME", "investigate-bff"),
		ReadTimeout:  getEnvDuration("HTTP_READ_TIMEOUT", 5*time.Second),
		WriteTimeout: getEnvDuration("HTTP_WRITE_TIMEOUT", 10*time.Second),
		IdleTimeout:  getEnvDuration("HTTP_IDLE_TIMEOUT", 120*time.Second),
	}, nil
}

func getEnv(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}

func getEnvDuration(key string, fallback time.Duration) time.Duration {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}

	if duration, err := time.ParseDuration(value); err == nil {
		return duration
	}

	if seconds, err := strconv.Atoi(value); err == nil {
		return time.Duration(seconds) * time.Second
	}

	return fallback
}
