package main

import (
	"log/slog"
	"os"

	"github.com/zabisa/platform/packages/go/platform/config"
	"github.com/zabisa/platform/packages/go/platform/httpx"
	"github.com/zabisa/platform/packages/go/platform/server"
)

func main() {
	cfg := config.Load("api-gateway", "", 8080)
	if err := cfg.ValidateRuntime(false); err != nil {
		slog.Error("invalid config", "error", err)
		os.Exit(1)
	}

	handler := newGatewayHandler(cfg, defaultTargets())
	if err := server.Run(cfg.Port, httpx.Middleware(cfg.Service, cfg.AllowedOrigins, handler)); err != nil {
		slog.Error("server", "error", err)
		os.Exit(1)
	}
}
