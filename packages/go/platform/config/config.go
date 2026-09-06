package config

import (
	"errors"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

const (
	ModeServe               = "serve"
	ModeMigrate             = "migrate"
	ModeServeWithMigrations = "serve-with-migrations"

	MySQLTLSDisabled       = "disabled"
	MySQLTLSVerifyCA       = "verify-ca"
	MySQLTLSVerifyIdentity = "verify-identity"
)

type Config struct {
	Service            string
	Port               int
	Environment        string
	Mode               string
	DBName             string
	MySQLHost          string
	MySQLPort          int
	MySQLUser          string
	MySQLPassword      string
	MySQLTLSMode       string
	MySQLTLSCAFile     string
	MySQLTLSServerName string
	JWTKey             string
	InternalServiceKey string
	AllowedOrigins     []string
	loadErrors         []error
}

func Load(service, dbName string, defaultPort int) Config {
	environment := env("ENVIRONMENT", "local")
	modeDefault := ModeServe
	if environment == "local" {
		modeDefault = ModeServeWithMigrations
	}

	mysqlUser, mysqlUserErr := secret("MYSQL_USER", "zabisa")
	mysqlPassword, mysqlPasswordErr := secret("MYSQL_PASSWORD", "")
	jwtKey, jwtErr := secret("JWT_SIGNING_KEY", "")
	internalKey, internalErr := secret("INTERNAL_SERVICE_KEY", "")

	var loadErrors []error
	for _, err := range []error{mysqlUserErr, mysqlPasswordErr, jwtErr, internalErr} {
		if err != nil {
			loadErrors = append(loadErrors, err)
		}
	}

	return Config{
		Service:            service,
		Port:               envInt("PORT", defaultPort),
		Environment:        environment,
		Mode:               strings.ToLower(env("APP_MODE", modeDefault)),
		DBName:             dbName,
		MySQLHost:          env("MYSQL_HOST", "127.0.0.1"),
		MySQLPort:          envInt("MYSQL_PORT", 3306),
		MySQLUser:          mysqlUser,
		MySQLPassword:      mysqlPassword,
		MySQLTLSMode:       strings.ToLower(env("MYSQL_TLS_MODE", MySQLTLSDisabled)),
		MySQLTLSCAFile:     strings.TrimSpace(os.Getenv("MYSQL_TLS_CA_FILE")),
		MySQLTLSServerName: env("MYSQL_TLS_SERVER_NAME", env("MYSQL_HOST", "127.0.0.1")),
		JWTKey:             jwtKey,
		InternalServiceKey: internalKey,
		AllowedOrigins:     splitCSV(env("CORS_ALLOWED_ORIGINS", "http://localhost:3001,http://localhost:8081")),
		loadErrors:         loadErrors,
	}
}

func (c Config) DSN() string {
	return fmt.Sprintf("%s:%s@tcp(%s:%d)/%s?parseTime=true&charset=utf8mb4&collation=utf8mb4_unicode_ci&loc=UTC&timeout=5s&readTimeout=5s&writeTimeout=5s", c.MySQLUser, c.MySQLPassword, c.MySQLHost, c.MySQLPort, c.DBName)
}

func (c Config) ShouldMigrate() bool {
	return c.Mode == ModeMigrate || c.Mode == ModeServeWithMigrations
}

func (c Config) MigrateOnly() bool { return c.Mode == ModeMigrate }

// ValidateRuntime makes secret-file and transport failures fatal at process
// startup. Migration-only mode deliberately does not require JWT/internal-service
// secrets because the migration Job has no reason to receive application auth
// material.
func (c Config) ValidateRuntime(requireDB bool) error {
	var errs []error
	errs = append(errs, c.loadErrors...)

	switch c.Mode {
	case ModeServe, ModeMigrate, ModeServeWithMigrations:
	default:
		errs = append(errs, fmt.Errorf("APP_MODE must be one of %q, %q, %q", ModeServe, ModeMigrate, ModeServeWithMigrations))
	}

	if c.Mode != ModeMigrate {
		if len(c.JWTKey) < 24 {
			errs = append(errs, fmt.Errorf("JWT_SIGNING_KEY must be at least 24 characters"))
		}
		if len(c.InternalServiceKey) < 24 {
			errs = append(errs, fmt.Errorf("INTERNAL_SERVICE_KEY must be at least 24 characters"))
		}
	}

	if requireDB {
		if strings.TrimSpace(c.MySQLUser) == "" {
			errs = append(errs, fmt.Errorf("MYSQL_USER must not be empty"))
		}
		if c.MySQLPassword == "" {
			errs = append(errs, fmt.Errorf("MYSQL_PASSWORD must not be empty"))
		}
		if c.Environment != "local" && c.MySQLTLSMode == MySQLTLSDisabled {
			errs = append(errs, fmt.Errorf("MYSQL_TLS_MODE=disabled is not allowed outside local development"))
		}
		switch c.MySQLTLSMode {
		case MySQLTLSDisabled:
		case MySQLTLSVerifyCA, MySQLTLSVerifyIdentity:
			if c.MySQLTLSCAFile == "" {
				errs = append(errs, fmt.Errorf("MYSQL_TLS_CA_FILE is required for MYSQL_TLS_MODE=%s", c.MySQLTLSMode))
			} else if st, err := os.Stat(c.MySQLTLSCAFile); err != nil {
				errs = append(errs, fmt.Errorf("MYSQL_TLS_CA_FILE %q: %w", c.MySQLTLSCAFile, err))
			} else if !st.Mode().IsRegular() {
				errs = append(errs, fmt.Errorf("MYSQL_TLS_CA_FILE %q is not a regular file", c.MySQLTLSCAFile))
			}
			if c.MySQLTLSMode == MySQLTLSVerifyIdentity && strings.TrimSpace(c.MySQLTLSServerName) == "" {
				errs = append(errs, fmt.Errorf("MYSQL_TLS_SERVER_NAME is required for verify-identity"))
			}
		default:
			errs = append(errs, fmt.Errorf("MYSQL_TLS_MODE must be one of %q, %q, %q", MySQLTLSDisabled, MySQLTLSVerifyCA, MySQLTLSVerifyIdentity))
		}
	}
	return errors.Join(errs...)
}

func (c Config) ValidateAuth() error { return c.ValidateRuntime(false) }

func env(k, fallback string) string {
	if v := strings.TrimSpace(os.Getenv(k)); v != "" {
		return v
	}
	return fallback
}

// Env returns a trimmed environment value or fallback when it is unset.
func Env(key, fallback string) string { return env(key, fallback) }

// secret supports the conventional KEY_FILE form used by Vault Agent rendered
// files. KEY_FILE deliberately takes precedence over KEY so Kubernetes manifests
// can guarantee Vault is the runtime source of truth while docker-compose/local
// development remains compatible with direct environment variables.
func secret(k, fallback string) (string, error) {
	if path := strings.TrimSpace(os.Getenv(k + "_FILE")); path != "" {
		b, err := os.ReadFile(path)
		if err != nil {
			return "", fmt.Errorf("read %s_FILE %q: %w", k, path, err)
		}
		v := strings.TrimSpace(string(b))
		if v == "" {
			return "", fmt.Errorf("%s_FILE %q is empty", k, path)
		}
		return v, nil
	}
	if v := strings.TrimSpace(os.Getenv(k)); v != "" {
		return v, nil
	}
	return fallback, nil
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
