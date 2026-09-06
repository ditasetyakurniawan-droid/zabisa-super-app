package main

import (
	"context"
	"database/sql"
	"embed"
	"net/http"
	"strings"
	"time"

	"github.com/zabisa/platform/packages/go/platform/access"
	"github.com/zabisa/platform/packages/go/platform/auditx"
	"github.com/zabisa/platform/packages/go/platform/authz"
	"github.com/zabisa/platform/packages/go/platform/config"
	"github.com/zabisa/platform/packages/go/platform/database"
	"github.com/zabisa/platform/packages/go/platform/httpx"
	"github.com/zabisa/platform/packages/go/platform/outbox"
	"github.com/zabisa/platform/packages/go/platform/service"
)

//go:embed migrations/*.sql
var migrationFS embed.FS

type app struct {
	db     *sql.DB
	cfg    config.Config
	access access.Control
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
	service.MustRun(service.Options{Name: "content-service", Database: "content_db", Port: 8082, Migrations: migrationFS, Build: buildService})
}

func buildService(ctx context.Context, db *sql.DB, cfg config.Config) (http.Handler, error) {
	a := &app{db: db, cfg: cfg, access: access.Control{JWTKey: cfg.JWTKey, InternalKey: cfg.InternalServiceKey}}
	go outbox.Worker{DB: db, Endpoint: config.Env("NOTIFICATION_SERVICE_URL", "http://notification:8087/internal/v1/events"), AuditEndpoint: config.Env("AUDIT_SERVICE_URL", "http://identity:8081/internal/v1/audit-events"), InternalKey: cfg.InternalServiceKey, Service: cfg.Service}.Run(ctx)
	routes := service.Router(db)
	routes.Handle("GET", "/api/v1/kajian", a.listKajian)
	routes.Handle("GET", "/api/v1/kajian/{id}", a.getKajian)
	routes.Handle("POST", "/api/v1/admin/kajian", a.access.RequirePermission(authz.KajianWrite, a.createKajian))
	routes.Handle("GET", "/api/v1/admin/kajian", a.access.RequirePermission(authz.KajianRead, a.listKajianAdmin))
	routes.Handle("PATCH", "/api/v1/admin/kajian/{id}", a.access.RequirePermission(authz.KajianWrite, a.updateKajian))
	routes.Handle("GET", "/api/v1/content", a.listContent)
	routes.Handle("GET", "/api/v1/content/{id}", a.getContent)
	routes.Handle("GET", "/api/v1/admin/content", a.access.RequirePermission(authz.ContentRead, a.listContentAdmin))
	routes.Handle("POST", "/api/v1/admin/content", a.access.RequirePermission(authz.ContentWrite, a.createContent))
	routes.Handle("PATCH", "/api/v1/admin/content/{id}", a.access.RequirePermission(authz.ContentWrite, a.updateContent))
	return routes, nil
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
		items = append(items, map[string]any{"id": id, "title": title, "slug": slug, "description": desc, "speaker": speaker.String, "start_at": start, "end_at": database.NullableTime(end), "location": location.String, "map_url": mapURL.String, "live_url": liveURL.String, "poster_url": posterURL.String, "status": status.String})
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
	httpx.JSON(w, 200, map[string]any{"id": id, "title": title, "slug": slug, "description": desc, "speaker": speaker.String, "start_at": start, "end_at": database.NullableTime(end), "location": location.String, "map_url": mapURL.String, "live_url": liveURL.String, "poster_url": posterURL.String, "status": status.String})
}
func (a *app) createKajian(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	actor, _ := a.access.Claims(r)
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
			out = append(out, map[string]any{"id": id, "type": t, "title": title, "slug": slug, "summary": summary.String, "image_url": image.String, "published_at": database.NullableTime(pub)})
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
