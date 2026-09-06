package service

import (
	"context"
	"database/sql"
	"io/fs"
	"log/slog"
	"net/http"
	"os"

	"github.com/zabisa/platform/packages/go/platform/config"
	"github.com/zabisa/platform/packages/go/platform/database"
	"github.com/zabisa/platform/packages/go/platform/health"
	"github.com/zabisa/platform/packages/go/platform/httpx"
	"github.com/zabisa/platform/packages/go/platform/migrate"
	"github.com/zabisa/platform/packages/go/platform/router"
	"github.com/zabisa/platform/packages/go/platform/server"
)

type BuildHandler func(context.Context, *sql.DB, config.Config) (http.Handler, error)

type Options struct {
	Name       string
	Database   string
	Port       int
	Migrations fs.FS
	Build      BuildHandler
}

var (
	loadConfig   = config.Load
	openDatabase = database.Open
	applySchema  = migrate.Apply
	runServer    = server.Run
	exitProcess  = os.Exit
)

// MustRun owns the common database, migration, lifecycle, and HTTP server
// bootstrap shared by database-backed services.
func MustRun(options Options) {
	if err := Run(options); err != nil {
		slog.Error("service stopped", "service", options.Name, "error", err)
		exitProcess(1)
	}
}

func Run(options Options) error {
	cfg := loadConfig(options.Name, options.Database, options.Port)
	if err := cfg.ValidateRuntime(true); err != nil {
		return err
	}
	db, err := openDatabase(context.Background(), cfg.DSN(), database.TLSOptions{
		Mode: cfg.MySQLTLSMode, CAFile: cfg.MySQLTLSCAFile, ServerName: cfg.MySQLTLSServerName,
	})
	if err != nil {
		return err
	}
	defer db.Close()
	if cfg.ShouldMigrate() {
		if err := applySchema(context.Background(), db, options.Migrations, "migrations"); err != nil {
			return err
		}
		if cfg.MigrateOnly() {
			slog.Info("database migrations complete", "service", cfg.Service, "database", cfg.DBName)
			return nil
		}
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	handler, err := options.Build(ctx, db, cfg)
	if err != nil {
		return err
	}
	return runServer(cfg.Port, httpx.Middleware(cfg.Service, cfg.AllowedOrigins, handler))
}

func Router(db *sql.DB) *router.Router {
	routes := router.New()
	routes.Handle(http.MethodGet, "/health/live", health.Live)
	routes.Handle(http.MethodGet, "/health/ready", health.Ready(db))
	return routes
}
