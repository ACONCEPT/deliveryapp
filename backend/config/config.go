package config

import (
	"fmt"
	"log"
	"os"
	"strconv"
)

// Config holds all application configuration
type Config struct {
	DatabaseURL     string
	ServerPort      string
	JWTSecret       string
	TokenDuration   int // in hours
	Environment     string
}

// Load reads configuration from environment variables
func Load() (*Config, error) {
	config := &Config{
		DatabaseURL:   getEnv("DATABASE_URL", ""),
		ServerPort:    getEnv("SERVER_PORT", "8080"),
		JWTSecret:     getEnv("JWT_SECRET", ""),
		TokenDuration: getEnvAsInt("TOKEN_DURATION", 72), // 3 days default
		Environment:   getEnv("ENVIRONMENT", "development"),
	}

	// Validate required fields
	if config.DatabaseURL == "" {
		return nil, fmt.Errorf("DATABASE_URL is required")
	}

	if config.JWTSecret == "" {
		return nil, fmt.Errorf("JWT_SECRET is required")
	}

	// Log JWT secret info for debugging (DO NOT log actual secret in production)
	if config.Environment == "development" {
		log.Printf("[CONFIG] JWT_SECRET loaded (length: %d chars, first 4: %s...)",
			len(config.JWTSecret),
			config.JWTSecret[:min(4, len(config.JWTSecret))])
	}

	return config, nil
}

// getEnv retrieves an environment variable or returns a default value
func getEnv(key, defaultValue string) string {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}
	return value
}

// getEnvAsInt retrieves an environment variable as an integer or returns a default value
func getEnvAsInt(key string, defaultValue int) int {
	valueStr := os.Getenv(key)
	if valueStr == "" {
		return defaultValue
	}

	value, err := strconv.Atoi(valueStr)
	if err != nil {
		return defaultValue
	}

	return value
}

// min returns the minimum of two integers
func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
