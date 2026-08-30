package main

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"strings"
	"time"

	"github.com/zabisa/platform/packages/go/platform/auth"
	"github.com/zabisa/platform/packages/go/platform/authz"
	"github.com/zabisa/platform/packages/go/platform/config"
	"github.com/zabisa/platform/packages/go/platform/httpx"
	"github.com/zabisa/platform/packages/go/platform/server"
)

type target struct {
	prefix string
	url    *url.URL
}

type guardianStudentsEnvelope struct {
	Data []struct {
		ID string `json:"id"`
	} `json:"data"`
}
type sessionStatusEnvelope struct {
	Data struct {
		Active bool   `json:"active"`
		UserID string `json:"user_id"`
		Role   string `json:"role"`
		Status string `json:"status"`
	} `json:"data"`
}

func main() {
	cfg := config.Load("api-gateway", "", 8080)
	targets := []target{
		must("/api/v1/auth", "http://identity:8081"), must("/api/v1/admin/guardian-candidates", "http://identity:8081"), must("/api/v1/admin/notification-candidates", "http://identity:8081"), must("/api/v1/admin/users", "http://identity:8081"), must("/api/v1/admin/audit-logs", "http://identity:8081"),
		must("/api/v1/kajian", "http://content:8082"), must("/api/v1/content", "http://content:8082"), must("/api/v1/admin/kajian", "http://content:8082"), must("/api/v1/admin/content", "http://content:8082"),
		must("/api/v1/guardian", "http://student:8083"), must("/api/v1/admin/students", "http://student:8083"), must("/api/v1/admin/guardian-links", "http://student:8083"), must("/api/v1/admin/attendance", "http://student:8083"),
		must("/api/v1/tahfidz", "http://tahfidz:8084"),
		must("/api/v1/subjects", "http://academic:8085"), must("/api/v1/grades", "http://academic:8085"), must("/api/v1/students", "http://academic:8085"), must("/api/v1/admin/subjects", "http://academic:8085"), must("/api/v1/admin/grades", "http://academic:8085"), must("/api/v1/admin/reports", "http://academic:8085"),
		must("/api/v1/donation", "http://donation:8086"), must("/api/v1/donations", "http://donation:8086"), must("/api/v1/admin/donation", "http://donation:8086"), must("/api/v1/admin/donations", "http://donation:8086"),
		must("/api/v1/notifications", "http://notification:8087"), must("/api/v1/devices", "http://notification:8087"), must("/api/v1/admin/notifications", "http://notification:8087"),
	}
	h := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/health/live" {
			httpx.JSON(w, 200, map[string]string{"status": "ok"})
			return
		}
		if raw := strings.TrimSpace(strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")); raw != "" {
			if claims, err := auth.Verify(cfg.JWTKey, raw); err == nil {
				ok, dependencyOK := activeSession(cfg, claims)
				if !dependencyOK {
					httpx.Fail(w, r, http.StatusServiceUnavailable, "IDENTITY_UNAVAILABLE", "Session validation temporarily unavailable")
					return
				}
				if !ok {
					httpx.Fail(w, r, http.StatusUnauthorized, "SESSION_REVOKED", "Session is no longer active; sign in again")
					return
				}
			}
		}
		if protectedStudentPath(r.URL.Path) {
			if ok := guardianObjectAccess(cfg, r); !ok {
				httpx.Fail(w, r, 403, "FORBIDDEN", "Student is not linked to this guardian")
				return
			}
		}
		for _, t := range targets {
			if strings.HasPrefix(r.URL.Path, t.prefix) {
				p := httputil.NewSingleHostReverseProxy(t.url)
				p.ErrorHandler = func(w http.ResponseWriter, r *http.Request, e error) {
					slog.Error("upstream failure", "error", e, "path", r.URL.Path)
					httpx.Fail(w, r, 502, "UPSTREAM_UNAVAILABLE", "Service temporarily unavailable")
				}
				p.ServeHTTP(w, r)
				return
			}
		}
		httpx.Fail(w, r, 404, "NOT_FOUND", "Route not found")
	})
	if err := server.Run(cfg.Port, httpx.Middleware(cfg.Service, cfg.AllowedOrigins, h)); err != nil {
		slog.Error("server", "error", err)
		os.Exit(1)
	}
}

func protectedStudentPath(path string) bool {
	return strings.HasPrefix(path, "/api/v1/tahfidz/students/") || (strings.HasPrefix(path, "/api/v1/students/") && (strings.HasSuffix(path, "/grades") || strings.HasSuffix(path, "/reports")))
}

func guardianObjectAccess(cfg config.Config, r *http.Request) bool {
	raw := strings.TrimSpace(strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer "))
	claims, err := auth.Verify(cfg.JWTKey, raw)
	if err != nil {
		return false
	}
	if claims.Role != "GUARDIAN" && claims.Role != "WALI_SANTRI" {
		return true
	}
	parts := strings.Split(strings.Trim(r.URL.Path, "/"), "/")
	var studentID string
	for i, p := range parts {
		if p == "students" && i+1 < len(parts) {
			studentID = parts[i+1]
			break
		}
	}
	if studentID == "" {
		return false
	}
	req, err := http.NewRequestWithContext(r.Context(), http.MethodGet, "http://student:8083/api/v1/guardian/students", nil)
	if err != nil {
		return false
	}
	req.Header.Set("Authorization", r.Header.Get("Authorization"))
	res, err := (&http.Client{Timeout: 4 * time.Second}).Do(req)
	if err != nil {
		return false
	}
	defer res.Body.Close()
	if res.StatusCode != 200 {
		return false
	}
	var body guardianStudentsEnvelope
	if json.NewDecoder(res.Body).Decode(&body) != nil {
		return false
	}
	for _, student := range body.Data {
		if student.ID == studentID {
			return true
		}
	}
	return false
}

func activeSession(cfg config.Config, claims auth.Claims) (bool, bool) {
	if claims.SessionID == "" {
		return false, true
	}
	req, err := http.NewRequest(http.MethodGet, "http://identity:8081/internal/v1/sessions/"+claims.SessionID, nil)
	if err != nil {
		return false, false
	}
	req.Header.Set("X-Internal-Key", cfg.InternalServiceKey)
	res, err := (&http.Client{Timeout: 2 * time.Second}).Do(req)
	if err != nil {
		return false, false
	}
	defer res.Body.Close()
	if res.StatusCode == http.StatusNotFound {
		return false, true
	}
	if res.StatusCode != http.StatusOK {
		return false, false
	}
	var body sessionStatusEnvelope
	if json.NewDecoder(res.Body).Decode(&body) != nil {
		return false, false
	}
	if !body.Data.Active || body.Data.UserID != claims.Sub {
		return false, true
	}
	// Reject stale JWT role immediately after an administrator changes access.
	if authz.NormalizeRole(body.Data.Role) != authz.NormalizeRole(claims.Role) {
		return false, true
	}
	return true, true
}

func must(prefix, raw string) target {
	u, err := url.Parse(raw)
	if err != nil {
		panic(err)
	}
	return target{prefix, u}
}
