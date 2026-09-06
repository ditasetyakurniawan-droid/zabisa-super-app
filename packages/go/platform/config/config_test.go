package config

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func writeSecretFile(t *testing.T, name, value string) string {
	t.Helper()
	p := filepath.Join(t.TempDir(), name)
	if err := os.WriteFile(p, []byte(value+"\n"), 0o400); err != nil {
		t.Fatal(err)
	}
	return p
}

func TestLoadPrefersSecretFiles(t *testing.T) {
	t.Setenv("MYSQL_USER", "wrong-env-user")
	t.Setenv("MYSQL_PASSWORD", "wrong-env-password")
	t.Setenv("JWT_SIGNING_KEY", "wrong-env-jwt-value-that-is-long-enough")
	t.Setenv("INTERNAL_SERVICE_KEY", "wrong-env-internal-value-that-is-long-enough")
	t.Setenv("MYSQL_USER_FILE", writeSecretFile(t, "mysql-user", "vault-user"))
	t.Setenv("MYSQL_PASSWORD_FILE", writeSecretFile(t, "mysql-password", "vault-password"))
	t.Setenv("JWT_SIGNING_KEY_FILE", writeSecretFile(t, "jwt", "vault-jwt-signing-key-that-is-long-enough"))
	t.Setenv("INTERNAL_SERVICE_KEY_FILE", writeSecretFile(t, "internal", "vault-internal-service-key-long-enough"))

	cfg := Load("test", "test_db", 8080)
	if err := cfg.ValidateRuntime(true); err != nil {
		t.Fatalf("ValidateRuntime: %v", err)
	}
	if cfg.MySQLUser != "vault-user" || cfg.MySQLPassword != "vault-password" {
		t.Fatalf("database secret files did not take precedence: %#v", cfg)
	}
	if !strings.HasPrefix(cfg.JWTKey, "vault-") || !strings.HasPrefix(cfg.InternalServiceKey, "vault-") {
		t.Fatal("runtime secret files did not take precedence")
	}
}

func TestMissingSecretFileFailsFast(t *testing.T) {
	t.Setenv("JWT_SIGNING_KEY_FILE", filepath.Join(t.TempDir(), "missing"))
	t.Setenv("INTERNAL_SERVICE_KEY", "local-internal-service-key-long-enough")

	cfg := Load("gateway", "", 8080)
	err := cfg.ValidateRuntime(false)
	if err == nil || !strings.Contains(err.Error(), "JWT_SIGNING_KEY_FILE") {
		t.Fatalf("expected missing secret file error, got %v", err)
	}
}

func TestDTDatabaseRuntimeRequiresTLS(t *testing.T) {
	t.Setenv("ENVIRONMENT", "dt")
	t.Setenv("APP_MODE", ModeServe)
	t.Setenv("MYSQL_USER", "runtime-user")
	t.Setenv("MYSQL_PASSWORD", "runtime-password")
	t.Setenv("JWT_SIGNING_KEY", "jwt-signing-key-that-is-long-enough")
	t.Setenv("INTERNAL_SERVICE_KEY", "internal-service-key-that-is-long-enough")
	t.Setenv("MYSQL_TLS_MODE", MySQLTLSDisabled)

	cfg := Load("identity", "identity_db", 8081)
	err := cfg.ValidateRuntime(true)
	if err == nil || !strings.Contains(err.Error(), "MYSQL_TLS_MODE=disabled") {
		t.Fatalf("expected non-local plaintext DB rejection, got %v", err)
	}
}

func TestMigrateModeRequiresDBButNotApplicationAuthSecrets(t *testing.T) {
	ca := writeSecretFile(t, "mysql-ca.pem", "not-a-real-ca-for-config-validation")
	t.Setenv("ENVIRONMENT", "dt")
	t.Setenv("APP_MODE", ModeMigrate)
	t.Setenv("MYSQL_USER", "migrator")
	t.Setenv("MYSQL_PASSWORD", "migrator-password")
	t.Setenv("MYSQL_TLS_MODE", MySQLTLSVerifyCA)
	t.Setenv("MYSQL_TLS_CA_FILE", ca)
	t.Setenv("JWT_SIGNING_KEY", "")
	t.Setenv("INTERNAL_SERVICE_KEY", "")

	cfg := Load("identity", "identity_db", 8081)
	if err := cfg.ValidateRuntime(true); err != nil {
		t.Fatalf("migration-only mode should not require JWT/internal secrets: %v", err)
	}
	if !cfg.ShouldMigrate() || !cfg.MigrateOnly() {
		t.Fatal("migration-only mode flags are inconsistent")
	}
}

func TestEnvUsesTrimmedValueAndFallback(t *testing.T) {
	t.Setenv("ZABISA_TEST_ENV", "  configured  ")
	if got := Env("ZABISA_TEST_ENV", "fallback"); got != "configured" {
		t.Fatalf("Env configured value = %q", got)
	}
	t.Setenv("ZABISA_TEST_ENV", "")
	if got := Env("ZABISA_TEST_ENV", "fallback"); got != "fallback" {
		t.Fatalf("Env fallback = %q", got)
	}
}

func TestRuntimeValidationBranches(t *testing.T) {
	validSecrets := Config{Mode: ModeServe, JWTKey: strings.Repeat("j", 24), InternalServiceKey: strings.Repeat("i", 24)}
	if errs := validSecrets.validateMode(); len(errs) != 0 {
		t.Fatalf("valid mode errors = %v", errs)
	}
	if errs := (Config{Mode: "invalid"}).validateMode(); len(errs) != 1 {
		t.Fatalf("invalid mode errors = %v", errs)
	}
	if errs := validSecrets.validateAuthSecrets(); len(errs) != 0 {
		t.Fatalf("valid auth errors = %v", errs)
	}
	if errs := (Config{}).validateAuthSecrets(); len(errs) != 2 {
		t.Fatalf("invalid auth errors = %v", errs)
	}

	validDatabase := Config{Environment: "local", MySQLUser: "user", MySQLPassword: "password", MySQLTLSMode: MySQLTLSDisabled}
	if errs := validDatabase.validateDatabase(); len(errs) != 0 {
		t.Fatalf("valid local database errors = %v", errs)
	}
	if errs := (Config{Environment: "dt", MySQLTLSMode: "invalid"}).validateDatabase(); len(errs) < 3 {
		t.Fatalf("invalid database errors = %v", errs)
	}
	if errs := (Config{Environment: "dt", MySQLUser: "user", MySQLPassword: "password", MySQLTLSMode: MySQLTLSVerifyIdentity}).validateDatabase(); len(errs) != 2 {
		t.Fatalf("verify identity errors = %v", errs)
	}
	if errs := (Config{Environment: "dt", MySQLUser: "user", MySQLPassword: "password", MySQLTLSMode: MySQLTLSVerifyCA, MySQLTLSCAFile: filepath.Join(t.TempDir(), "missing")}).validateDatabase(); len(errs) != 1 {
		t.Fatalf("missing CA errors = %v", errs)
	}
	if errs := (Config{Environment: "dt", MySQLUser: "user", MySQLPassword: "password", MySQLTLSMode: MySQLTLSVerifyCA, MySQLTLSCAFile: t.TempDir()}).validateDatabase(); len(errs) != 1 {
		t.Fatalf("directory CA errors = %v", errs)
	}
}
