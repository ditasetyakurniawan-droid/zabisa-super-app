package main

import (
	"context"
	"database/sql"
	"embed"
	"github.com/zabisa/platform/packages/go/platform/auditx"
	"github.com/zabisa/platform/packages/go/platform/auth"
	"github.com/zabisa/platform/packages/go/platform/authz"
	"github.com/zabisa/platform/packages/go/platform/config"
	"github.com/zabisa/platform/packages/go/platform/database"
	"github.com/zabisa/platform/packages/go/platform/health"
	"github.com/zabisa/platform/packages/go/platform/httpx"
	"github.com/zabisa/platform/packages/go/platform/migrate"
	"github.com/zabisa/platform/packages/go/platform/outbox"
	"github.com/zabisa/platform/packages/go/platform/router"
	"github.com/zabisa/platform/packages/go/platform/server"
	"log/slog"
	"net/http"
	"os"
	"strings"
	"time"
)

//go:embed migrations/*.sql
var migrationFS embed.FS

type app struct {
	db  *sql.DB
	cfg config.Config
}
type kajianIn struct {
	Title       string     `json:"title"`
	Slug        string     `json:"slug"`
	Description string     `json:"description"`
	Speaker     string     `json:"speaker"`
	StartAt     time.Time  `json:"start_at"`
	EndAt       *time.Time `json:"end_at"`
	Location    string     `json:"location"`
	MapURL      string     `json:"map_url"`
	LiveURL     string     `json:"live_url"`
	PosterURL   string     `json:"poster_url"`
	Published   bool       `json:"published"`
}

func main() {
	cfg := config.Load("content-service", "content_db", 8082)
	if err := cfg.ValidateRuntime(true); err != nil {
		slog.Error("invalid config", "error", err)
		os.Exit(1)
	}
	db, err := database.Open(context.Background(), cfg.DSN(), database.TLSOptions{Mode: cfg.MySQLTLSMode, CAFile: cfg.MySQLTLSCAFile, ServerName: cfg.MySQLTLSServerName})
	if err != nil {
		slog.Error("db", "error", err)
		os.Exit(1)
	}
	defer db.Close()
	if cfg.ShouldMigrate() {
		if err = migrate.Apply(context.Background(), db, migrationFS, "migrations"); err != nil {
			slog.Error("migration", "error", err)
			os.Exit(1)
		}
		if cfg.MigrateOnly() {
			slog.Info("database migrations complete", "service", cfg.Service, "database", cfg.DBName)
			return
		}
	}
	a := &app{db, cfg}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go outbox.Worker{DB: db, Endpoint: envURL("NOTIFICATION_SERVICE_URL", "http://notification:8087/internal/v1/events"), AuditEndpoint: envURL("AUDIT_SERVICE_URL", "http://identity:8081/internal/v1/audit-events"), InternalKey: cfg.InternalServiceKey, Service: cfg.Service}.Run(ctx)
	rt := router.New()
	rt.Handle("GET", "/health/live", health.Live)
	rt.Handle("GET", "/health/ready", health.Ready(db))
	rt.Handle("GET", "/api/v1/kajian", a.listKajian)
	rt.Handle("GET", "/api/v1/kajian/{id}", a.getKajian)
	rt.Handle("POST", "/api/v1/admin/kajian", a.requirePermission(authz.KajianWrite, a.createKajian))
	rt.Handle("GET", "/api/v1/admin/kajian", a.requirePermission(authz.KajianRead, a.listKajianAdmin))
	rt.Handle("PATCH", "/api/v1/admin/kajian/{id}", a.requirePermission(authz.KajianWrite, a.updateKajian))
	rt.Handle("GET", "/api/v1/content", a.listContent)
	rt.Handle("GET", "/api/v1/content/{id}", a.getContent)
	rt.Handle("GET", "/api/v1/admin/content", a.requirePermission(authz.ContentRead, a.listContentAdmin))
	rt.Handle("POST", "/api/v1/admin/content", a.requirePermission(authz.ContentWrite, a.createContent))
	rt.Handle("PATCH", "/api/v1/admin/content/{id}", a.requirePermission(authz.ContentWrite, a.updateContent))
	if err = server.Run(cfg.Port, httpx.Middleware(cfg.Service, cfg.AllowedOrigins, rt)); err != nil {
		panic(err)
	}
}
func (a *app) requirePermission(permission authz.Permission, h router.HandlerFunc) router.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request, p map[string]string) {
		raw := strings.TrimSpace(strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer "))
		c, err := auth.Verify(a.cfg.JWTKey, raw)
		if err != nil {
			httpx.Fail(w, r, 401, "UNAUTHORIZED", "Authentication required")
			return
		}
		if !authz.Has(c.Role, permission) {
			httpx.Fail(w, r, 403, "FORBIDDEN", "Insufficient permission")
			return
		}
		h(w, r, p)
	}
}
func (a *app) listKajian(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	rows, err := a.db.QueryContext(r.Context(), `SELECT id,title,slug,description,speaker,start_at,end_at,location,map_url,live_url,poster_url,status FROM kajian WHERE published=TRUE ORDER BY start_at DESC LIMIT 100`)
	if err != nil {
		httpx.Fail(w, r, 500, "QUERY_FAILED", "Could not load kajian")
		return
	}
	defer rows.Close()
	items := []map[string]any{}
	for rows.Next() {
		var id, title, slug, desc string
		var speaker, location, mapURL, liveURL, posterURL, status sql.NullString
		var start time.Time
		var end sql.NullTime
		if rows.Scan(&id, &title, &slug, &desc, &speaker, &start, &end, &location, &mapURL, &liveURL, &posterURL, &status) != nil {
			continue
		}
		items = append(items, map[string]any{"id": id, "title": title, "slug": slug, "description": desc, "speaker": speaker.String, "start_at": start, "end_at": nullableTime(end), "location": location.String, "map_url": mapURL.String, "live_url": liveURL.String, "poster_url": posterURL.String, "status": status.String})
	}
	httpx.JSON(w, 200, items)
}
func (a *app) getKajian(w http.ResponseWriter, r *http.Request, p map[string]string) {
	var id, title, slug, desc string
	var speaker, location, mapURL, liveURL, posterURL, status sql.NullString
	var start time.Time
	var end sql.NullTime
	err := a.db.QueryRowContext(r.Context(), `SELECT id,title,slug,description,speaker,start_at,end_at,location,map_url,live_url,poster_url,status FROM kajian WHERE id=? AND published=TRUE`, p["id"]).Scan(&id, &title, &slug, &desc, &speaker, &start, &end, &location, &mapURL, &liveURL, &posterURL, &status)
	if err == sql.ErrNoRows {
		httpx.Fail(w, r, 404, "NOT_FOUND", "Kajian not found")
		return
	}
	if err != nil {
		httpx.Fail(w, r, 500, "QUERY_FAILED", "Could not load kajian")
		return
	}
	httpx.JSON(w, 200, map[string]any{"id": id, "title": title, "slug": slug, "description": desc, "speaker": speaker.String, "start_at": start, "end_at": nullableTime(end), "location": location.String, "map_url": mapURL.String, "live_url": liveURL.String, "poster_url": posterURL.String, "status": status.String})
}
func (a *app) createKajian(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	raw := strings.TrimSpace(strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer "))
	actor, _ := auth.Verify(a.cfg.JWTKey, raw)
	var in kajianIn
	if !httpx.Decode(w, r, &in) {
		return
	}
	if strings.TrimSpace(in.Title) == "" || strings.TrimSpace(in.Slug) == "" || strings.TrimSpace(in.Description) == "" || in.StartAt.IsZero() {
		httpx.Fail(w, r, 400, "VALIDATION", "Title, slug, description and start_at are required")
		return
	}
	id := httpx.NewID()
	status := "UPCOMING"
	if in.StartAt.Before(time.Now().UTC()) {
		status = "ONGOING"
	}
	tx, err := a.db.BeginTx(r.Context(), nil)
	if err == nil {
		_, err = tx.ExecContext(r.Context(), `INSERT INTO kajian(id,title,slug,description,speaker,start_at,end_at,location,map_url,live_url,poster_url,status,published) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)`, id, in.Title, in.Slug, in.Description, null(in.Speaker), in.StartAt, in.EndAt, null(in.Location), null(in.MapURL), null(in.LiveURL), null(in.PosterURL), status, in.Published)
	}
	if err == nil && in.Published {
		err = outbox.Add(r.Context(), tx, "KajianPublished", map[string]any{"kajian_id": id, "title": in.Title, "deep_link": "zabisa://kajian/" + id})
	}
	if err == nil {
		after := map[string]any{"title": in.Title, "slug": in.Slug, "speaker": strings.TrimSpace(in.Speaker), "start_at": in.StartAt, "location": strings.TrimSpace(in.Location), "published": in.Published, "status": status}
		err = auditx.Add(r.Context(), tx, auditx.FromRequest(r, actor.Sub, "KAJIAN_CREATED", "kajian", id, nil, after))
	}
	if err == nil {
		err = tx.Commit()
	} else if tx != nil {
		_ = tx.Rollback()
	}
	if err != nil {
		httpx.Fail(w, r, 409, "CREATE_FAILED", "Could not create kajian; slug may already exist")
		return
	}
	httpx.JSON(w, 201, map[string]any{"id": id, "status": status, "published": in.Published})
}
func (a *app) listContent(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	typ := strings.TrimSpace(r.URL.Query().Get("type"))
	rows, err := a.db.QueryContext(r.Context(), `SELECT id,type,title,slug,summary,image_url,published_at FROM contents WHERE published=TRUE AND (?='' OR type=?) ORDER BY published_at DESC LIMIT 100`, typ, typ)
	if err != nil {
		httpx.Fail(w, r, 500, "QUERY_FAILED", "Could not load content")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id, t, title, slug string
		var summary, image sql.NullString
		var pub sql.NullTime
		if rows.Scan(&id, &t, &title, &slug, &summary, &image, &pub) == nil {
			out = append(out, map[string]any{"id": id, "type": t, "title": title, "slug": slug, "summary": summary.String, "image_url": image.String, "published_at": nullableTime(pub)})
		}
	}
	httpx.JSON(w, 200, out)
}
func null(v string) any {
	if strings.TrimSpace(v) == "" {
		return nil
	}
	return strings.TrimSpace(v)
}
func nullableTime(v sql.NullTime) any {
	if !v.Valid {
		return nil
	}
	return v.Time
}

func envURL(key, fallback string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return fallback
}
