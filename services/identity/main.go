package main

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"database/sql"
	"embed"
	"encoding/hex"
	"log/slog"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/zabisa/platform/packages/go/platform/auth"
	"github.com/zabisa/platform/packages/go/platform/authz"
	"github.com/zabisa/platform/packages/go/platform/config"
	"github.com/zabisa/platform/packages/go/platform/database"
	"github.com/zabisa/platform/packages/go/platform/health"
	"github.com/zabisa/platform/packages/go/platform/httpx"
	"github.com/zabisa/platform/packages/go/platform/migrate"
	"github.com/zabisa/platform/packages/go/platform/router"
	"github.com/zabisa/platform/packages/go/platform/server"
)

//go:embed migrations/*.sql
var migrationFS embed.FS

type app struct {
	db  *sql.DB
	cfg config.Config
}
type loginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
	DeviceID string `json:"device_id"`
}
type refreshRequest struct {
	RefreshToken string `json:"refresh_token"`
}

func main() {
	cfg := config.Load("identity-service", "identity_db", 8081)
	if err := cfg.ValidateAuth(); err != nil {
		slog.Error("invalid config", "error", err)
		os.Exit(1)
	}
	ctx := context.Background()
	db, err := database.Open(ctx, cfg.DSN())
	if err != nil {
		slog.Error("database", "error", err)
		os.Exit(1)
	}
	defer db.Close()
	if err = migrate.Apply(ctx, db, migrationFS, "migrations"); err != nil {
		slog.Error("migration", "error", err)
		os.Exit(1)
	}
	a := &app{db: db, cfg: cfg}
	if cfg.Environment == "local" {
		if err = a.seedLocal(ctx); err != nil {
			slog.Error("seed", "error", err)
			os.Exit(1)
		}
	}
	rt := router.New()
	rt.Handle(http.MethodGet, "/health/live", health.Live)
	rt.Handle(http.MethodGet, "/health/ready", health.Ready(db))
	rt.Handle(http.MethodPost, "/api/v1/auth/login", a.login)
	rt.Handle(http.MethodPost, "/api/v1/auth/refresh", a.refresh)
	rt.Handle(http.MethodPost, "/api/v1/auth/logout", a.logout)
	rt.Handle(http.MethodGet, "/api/v1/auth/me", a.me)
	rt.Handle(http.MethodGet, "/internal/v1/sessions/{id}", a.internal(a.sessionStatus))
	rt.Handle(http.MethodPost, "/internal/v1/audit-events", a.internal(a.ingestAuditEvent))
	rt.Handle(http.MethodGet, "/api/v1/admin/users", a.requirePermission(authz.UsersRead, a.listUsers))
	rt.Handle(http.MethodGet, "/api/v1/admin/guardian-candidates", a.requirePermission(authz.GuardiansRead, a.listGuardianCandidates))
	rt.Handle(http.MethodGet, "/api/v1/admin/notification-candidates", a.requirePermission(authz.NotificationsRead, a.listNotificationCandidates))
	rt.Handle(http.MethodPost, "/api/v1/admin/users", a.requirePermission(authz.UsersWrite, a.createUser))
	rt.Handle(http.MethodPatch, "/api/v1/admin/users/{id}", a.requirePermission(authz.RolesWrite, a.updateUserAccess))
	rt.Handle(http.MethodGet, "/api/v1/admin/audit-logs", a.requirePermission(authz.AuditRead, a.listAuditLogs))
	if err = server.Run(cfg.Port, httpx.Middleware(cfg.Service, cfg.AllowedOrigins, rt)); err != nil {
		slog.Error("server", "error", err)
		os.Exit(1)
	}
}
func (a *app) seedLocal(ctx context.Context) error {
	seeds := []struct{ id, email, name, role string }{
		{"00000000-0000-4000-8000-000000000001", "admin@zabisa.local", "Development Admin", "SUPER_ADMIN"},
		{"00000000-0000-4000-8000-000000000002", "guardian@zabisa.local", "Wali Santri Demo", "GUARDIAN"},
		{"00000000-0000-4000-8000-000000000003", "ustadz@zabisa.local", "Ustadz Demo", "USTADZ"},
		{"00000000-0000-4000-8000-000000000004", "teacher@zabisa.local", "Guru Akademik Demo", "GURU_AKADEMIK"},
	}
	for _, seed := range seeds {
		var n int
		if err := a.db.QueryRowContext(ctx, `SELECT COUNT(*) FROM users WHERE email=?`, seed.email).Scan(&n); err != nil {
			return err
		}
		if n > 0 {
			continue
		}
		h, err := auth.HashPassword("ChangeMe123!")
		if err != nil {
			return err
		}
		if _, err = a.db.ExecContext(ctx, `INSERT INTO users(id,email,password_hash,display_name,role) VALUES(?,?,?,?,?)`, seed.id, seed.email, h, seed.name, seed.role); err != nil {
			return err
		}
	}
	return nil
}
func (a *app) login(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	var in loginRequest
	if !httpx.Decode(w, r, &in) {
		return
	}
	in.Email = strings.ToLower(strings.TrimSpace(in.Email))
	if in.Email == "" || in.Password == "" {
		httpx.Fail(w, r, 400, "VALIDATION", "Email and password are required")
		return
	}
	var id, hash, name, role, status string
	err := a.db.QueryRowContext(r.Context(), `SELECT id,password_hash,display_name,role,status FROM users WHERE email=?`, in.Email).Scan(&id, &hash, &name, &role, &status)
	if err != nil || status != "ACTIVE" || !auth.VerifyPassword(hash, in.Password) {
		time.Sleep(150 * time.Millisecond)
		httpx.Fail(w, r, 401, "INVALID_CREDENTIALS", "Invalid email or password")
		return
	}
	sid := httpx.NewID()
	refresh := randomToken()
	rh := sha256.Sum256([]byte(refresh))
	exp := time.Now().UTC().Add(30 * 24 * time.Hour)
	if _, err = a.db.ExecContext(r.Context(), `INSERT INTO sessions(id,user_id,refresh_hash,device_id,expires_at) VALUES(?,?,?,?,?)`, sid, id, hex.EncodeToString(rh[:]), nullIfEmpty(in.DeviceID), exp); err != nil {
		httpx.Fail(w, r, 500, "SESSION_CREATE_FAILED", "Could not create session")
		return
	}
	access, _ := auth.Sign(a.cfg.JWTKey, auth.AccessClaims(id, role, sid, 15*time.Minute))
	httpx.JSON(w, 200, map[string]any{"access_token": access, "refresh_token": refresh, "expires_in": 900, "user": map[string]string{"id": id, "name": name, "role": role}})
}
func (a *app) refresh(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	var in refreshRequest
	if !httpx.Decode(w, r, &in) {
		return
	}
	h := sha256.Sum256([]byte(in.RefreshToken))
	var sid, uid, role string
	var exp time.Time
	err := a.db.QueryRowContext(r.Context(), `SELECT s.id,s.user_id,u.role,s.expires_at FROM sessions s JOIN users u ON u.id=s.user_id WHERE s.refresh_hash=? AND s.revoked_at IS NULL`, hex.EncodeToString(h[:])).Scan(&sid, &uid, &role, &exp)
	if err != nil || time.Now().UTC().After(exp) {
		httpx.Fail(w, r, 401, "INVALID_REFRESH", "Refresh token is invalid or expired")
		return
	}
	newRefresh := randomToken()
	nh := sha256.Sum256([]byte(newRefresh))
	newExp := time.Now().UTC().Add(30 * 24 * time.Hour)
	if _, err = a.db.ExecContext(r.Context(), `UPDATE sessions SET refresh_hash=?,expires_at=? WHERE id=?`, hex.EncodeToString(nh[:]), newExp, sid); err != nil {
		httpx.Fail(w, r, 500, "REFRESH_FAILED", "Could not rotate session")
		return
	}
	access, _ := auth.Sign(a.cfg.JWTKey, auth.AccessClaims(uid, role, sid, 15*time.Minute))
	httpx.JSON(w, 200, map[string]any{"access_token": access, "refresh_token": newRefresh, "expires_in": 900})
}
func (a *app) logout(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	raw := strings.TrimSpace(strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer "))
	c, err := auth.Verify(a.cfg.JWTKey, raw)
	if err != nil {
		httpx.Fail(w, r, 401, "UNAUTHORIZED", "Authentication required")
		return
	}
	_, _ = a.db.ExecContext(r.Context(), `UPDATE sessions SET revoked_at=UTC_TIMESTAMP(6) WHERE id=?`, c.SessionID)
	w.WriteHeader(http.StatusNoContent)
}
func randomToken() string { b := make([]byte, 32); _, _ = rand.Read(b); return hex.EncodeToString(b) }
func nullIfEmpty(v string) any {
	if strings.TrimSpace(v) == "" {
		return nil
	}
	return strings.TrimSpace(v)
}
