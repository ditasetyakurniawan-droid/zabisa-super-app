package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	Service            string
	Port               int
	Environment        string
	DBName             string
	MySQLHost          string
	MySQLPort          int
	MySQLUser          string
	MySQLPassword      string
	JWTKey             string
	InternalServiceKey string
	AllowedOrigins     []string
}

func Load(service, dbName string, defaultPort int) Config {
	return Config{
		Service:            service,
		Port:               envInt("PORT", defaultPort),
		Environment:        env("ENVIRONMENT", "local"),
		DBName:             dbName,
		MySQLHost:          env("MYSQL_HOST", "127.0.0.1"),
		MySQLPort:          envInt("MYSQL_PORT", 3306),
		MySQLUser:          env("MYSQL_USER", "zabisa"),
		MySQLPassword:      os.Getenv("MYSQL_PASSWORD"),
		JWTKey:             os.Getenv("JWT_SIGNING_KEY"),
		InternalServiceKey: os.Getenv("INTERNAL_SERVICE_KEY"),
		AllowedOrigins:     splitCSV(env("CORS_ALLOWED_ORIGINS", "http://localhost:3001,http://localhost:8081")),
	}
}

func (c Config) DSN() string {
	return fmt.Sprintf("%s:%s@tcp(%s:%d)/%s?parseTime=true&charset=utf8mb4&collation=utf8mb4_unicode_ci&loc=UTC&timeout=5s&readTimeout=5s&writeTimeout=5s", c.MySQLUser, c.MySQLPassword, c.MySQLHost, c.MySQLPort, c.DBName)
}

func (c Config) ValidateAuth() error {
	if len(c.JWTKey) < 24 {
		return fmt.Errorf("JWT_SIGNING_KEY must be at least 24 characters")
	}
	return nil
}

func env(k, fallback string) string {
	if v := strings.TrimSpace(os.Getenv(k)); v != "" {
		return v
	}
	return fallback
}
func envInt(k string, fallback int) int {
	v, err := strconv.Atoi(env(k, ""))
	if err != nil {
		return fallback
	}
	return v
}
func splitCSV(v string) []string {
	var out []string
	for _, s := range strings.Split(v, ",") {
		if t := strings.TrimSpace(s); t != "" {
			out = append(out, t)
		}
	}
	return out
}

const ShutdownTimeout = 10 * time.Second
