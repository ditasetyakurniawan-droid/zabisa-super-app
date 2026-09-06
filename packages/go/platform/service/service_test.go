package service

import (
	"context"
	"database/sql"
	"errors"
	"io/fs"
	"net/http"
	"testing"

	"github.com/zabisa/platform/packages/go/platform/config"
	"github.com/zabisa/platform/packages/go/platform/database"
)

func validConfig(mode string) config.Config {
	return config.Config{
		Service: "test-service", Port: 9090, Environment: "local", Mode: mode,
		DBName: "test_db", MySQLUser: "test", MySQLPassword: "secret",
		MySQLTLSMode: config.MySQLTLSDisabled, JWTKey: "012345678901234567890123",
		InternalServiceKey: "012345678901234567890123",
	}
}

func withFakes(t *testing.T, cfg config.Config) {
	t.Helper()
	originalLoad, originalOpen, originalApply, originalServer, originalExit := loadConfig, openDatabase, applySchema, runServer, exitProcess
	t.Cleanup(func() {
		loadConfig, openDatabase, applySchema, runServer = originalLoad, originalOpen, originalApply, originalServer
		exitProcess = originalExit
	})
	loadConfig = func(string, string, int) config.Config { return cfg }
	openDatabase = func(context.Context, string, database.TLSOptions) (*sql.DB, error) {
		return sql.Open("mysql", "test:secret@tcp(127.0.0.1:1)/test_db")
	}
}

func TestMustRunReportsFailure(t *testing.T) {
	withFakes(t, config.Config{})
	exitCode := 0
	exitProcess = func(code int) { exitCode = code }
	MustRun(Options{Name: "invalid-service"})
	if exitCode != 1 {
		t.Fatalf("exit code = %d", exitCode)
	}
}

func TestRunFailurePaths(t *testing.T) {
	t.Run("invalid config", func(t *testing.T) {
		withFakes(t, config.Config{})
		if err := Run(Options{}); err == nil {
			t.Fatal("expected validation error")
		}
	})
	t.Run("database open", func(t *testing.T) {
		withFakes(t, validConfig(config.ModeServe))
		openDatabase = func(context.Context, string, database.TLSOptions) (*sql.DB, error) {
			return nil, errors.New("open failed")
		}
		if err := Run(Options{}); err == nil {
			t.Fatal("expected database error")
		}
	})
	t.Run("migration", func(t *testing.T) {
		withFakes(t, validConfig(config.ModeServeWithMigrations))
		applySchema = func(context.Context, *sql.DB, fs.FS, string) error {
			return errors.New("migration failed")
		}
		if err := Run(Options{}); err == nil {
			t.Fatal("expected migration error")
		}
	})
	t.Run("build", func(t *testing.T) {
		withFakes(t, validConfig(config.ModeServe))
		expected := errors.New("build failed")
		err := Run(Options{Build: func(context.Context, *sql.DB, config.Config) (http.Handler, error) {
			return nil, expected
		}})
		if !errors.Is(err, expected) {
			t.Fatalf("build error = %v", err)
		}
	})
}

func TestRunServe(t *testing.T) {
	withFakes(t, validConfig(config.ModeServe))
	built := false
	runServer = func(port int, handler http.Handler) error {
		if port != 9090 || handler == nil {
			t.Fatalf("server received port=%d handler=%v", port, handler)
		}
		return nil
	}
	err := Run(Options{Name: "test-service", Database: "test_db", Port: 9090, Build: func(context.Context, *sql.DB, config.Config) (http.Handler, error) {
		built = true
		return http.HandlerFunc(func(http.ResponseWriter, *http.Request) {}), nil
	}})
	if err != nil || !built {
		t.Fatalf("Run() error=%v built=%v", err, built)
	}
}

func TestRunMigrateOnly(t *testing.T) {
	withFakes(t, validConfig(config.ModeMigrate))
	applied := false
	applySchema = func(context.Context, *sql.DB, fs.FS, string) error {
		applied = true
		return nil
	}
	err := Run(Options{Name: "test-service", Database: "test_db", Port: 9090})
	if err != nil || !applied {
		t.Fatalf("Run() error=%v applied=%v", err, applied)
	}
}

func TestRouterIncludesLiveness(t *testing.T) {
	routes := Router(nil)
	request, err := http.NewRequest(http.MethodGet, "/health/live", nil)
	if err != nil {
		t.Fatal(err)
	}
	recorder := &responseRecorder{header: http.Header{}}
	routes.ServeHTTP(recorder, request)
	if recorder.status != http.StatusOK {
		t.Fatalf("liveness status = %d", recorder.status)
	}
}

type responseRecorder struct {
	header http.Header
	status int
}

func (r *responseRecorder) Header() http.Header            { return r.header }
func (r *responseRecorder) Write(body []byte) (int, error) { return len(body), nil }
func (r *responseRecorder) WriteHeader(status int)         { r.status = status }
