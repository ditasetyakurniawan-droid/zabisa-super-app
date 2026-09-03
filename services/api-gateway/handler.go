package main

import (
	"net/http"
	"strings"

	"github.com/zabisa/platform/packages/go/platform/auth"
	"github.com/zabisa/platform/packages/go/platform/config"
	"github.com/zabisa/platform/packages/go/platform/httpx"
)

type gatewayHandler struct {
	cfg     config.Config
	targets []target
}

func newGatewayHandler(cfg config.Config, targets []target) http.Handler {
	return &gatewayHandler{cfg: cfg, targets: targets}
}

func (g *gatewayHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if serveHealth(w, r) {
		return
	}

	if rawToken := bearerToken(r); rawToken != "" {
		if claims, err := auth.Verify(g.cfg.JWTKey, rawToken); err == nil {
			active, dependencyAvailable := activeSession(r.Context(), g.cfg, claims)
			if !dependencyAvailable {
				httpx.Fail(w, r, http.StatusServiceUnavailable, "IDENTITY_UNAVAILABLE", "Session validation temporarily unavailable")
				return
			}
			if !active {
				httpx.Fail(w, r, http.StatusUnauthorized, "SESSION_REVOKED", "Session is no longer active; sign in again")
				return
			}
		}
	}

	if protectedStudentPath(r.URL.Path) && !guardianObjectAccess(g.cfg, r) {
		httpx.Fail(w, r, http.StatusForbidden, "FORBIDDEN", "Student is not linked to this guardian")
		return
	}

	for _, target := range g.targets {
		if target.matches(r.URL.Path) {
			target.handler.ServeHTTP(w, r)
			return
		}
	}

	httpx.Fail(w, r, http.StatusNotFound, "NOT_FOUND", "Route not found")
}

func serveHealth(w http.ResponseWriter, r *http.Request) bool {
	switch r.URL.Path {
	case "/health/live":
		httpx.JSON(w, http.StatusOK, map[string]string{"status": "ok"})
		return true
	case "/health/ready":
		// Readiness is process-local for this stateless gateway. Each upstream
		// owns its own readiness probe, avoiding cascading gateway outages.
		httpx.JSON(w, http.StatusOK, map[string]string{"status": "ready"})
		return true
	default:
		return false
	}
}

func bearerToken(r *http.Request) string {
	return strings.TrimSpace(strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer "))
}
