package config

import (
	"fmt"
	"os"
	"time"
)

// Config holds runtime configuration sourced from the environment.
type Config struct {
	DatabaseURL string
	JWTSecret   string
	Port        string
	AccessTTL   time.Duration
	RefreshTTL  time.Duration
}

// Load reads config from env. DATABASE_URL and JWT_SECRET are required.
func Load() (Config, error) {
	c := Config{
		DatabaseURL: os.Getenv("DATABASE_URL"),
		JWTSecret:   os.Getenv("JWT_SECRET"),
		Port:        getenv("PORT", "8080"),
		AccessTTL:   time.Hour,
		RefreshTTL:  30 * 24 * time.Hour,
	}
	if c.DatabaseURL == "" {
		return c, fmt.Errorf("DATABASE_URL is required")
	}
	if c.JWTSecret == "" {
		return c, fmt.Errorf("JWT_SECRET is required")
	}
	return c, nil
}

func getenv(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}
