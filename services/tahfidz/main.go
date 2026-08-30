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
type entryIn struct {
	StudentID    string   `json:"student_id"`
	ActivityDate string   `json:"activity_date"`
	Surah        string   `json:"surah"`
	AyahStart    int      `json:"ayah_start"`
	AyahEnd      int      `json:"ayah_end"`
	Juz          *int     `json:"juz"`
	Page         *int     `json:"page"`
	ActivityType string   `json:"activity_type"`
	Score        *float64 `json:"score"`
	Fluency      string   `json:"fluency"`
	Tajwid       string   `json:"tajwid"`
	Makhraj      string   `json:"makhraj"`
	TeacherNote  string   `json:"teacher_note"`
}

func main() {
	cfg := config.Load("tahfidz-service", "tahfidz_db", 8084)
	db, err := database.Open(context.Background(), cfg.DSN())
	if err != nil {
		panic(err)
	}
	defer db.Close()
	if err = migrate.Apply(context.Background(), db, migrationFS, "migrations"); err != nil {
		panic(err)
	}
	a := &app{db, cfg}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go outbox.Worker{DB: db, Endpoint: envURL("NOTIFICATION_SERVICE_URL", "http://notification:8087/internal/v1/events"), AuditEndpoint: envURL("AUDIT_SERVICE_URL", "http://identity:8081/internal/v1/audit-events"), InternalKey: cfg.InternalServiceKey, Service: cfg.Service}.Run(ctx)
	rt := router.New()
	rt.Handle("GET", "/health/live", health.Live)
	rt.Handle("GET", "/health/ready", health.Ready(db))
	rt.Handle("POST", "/api/v1/tahfidz/entries", a.requirePermission(authz.TahfidzWrite, a.createEntry))
	rt.Handle("GET", "/api/v1/tahfidz/entries", a.requirePermission(authz.TahfidzRead, a.listEntriesAdmin))
	rt.Handle("POST", "/api/v1/tahfidz/targets", a.requirePermission(authz.TahfidzWrite, a.createTarget))
	rt.Handle("GET", "/api/v1/tahfidz/targets", a.requirePermission(authz.TahfidzRead, a.listTargets))
	rt.Handle("PATCH", "/api/v1/tahfidz/targets/{id}", a.requirePermission(authz.TahfidzWrite, a.updateTarget))
	rt.Handle("GET", "/api/v1/tahfidz/students/{id}/entries", a.studentScoped(authz.TahfidzRead, a.listEntries))
	if err = server.Run(cfg.Port, httpx.Middleware(cfg.Service, cfg.AllowedOrigins, rt)); err != nil {
		slog.Error("server", "error", err)
		os.Exit(1)
	}
}
func (a *app) claims(r *http.Request) (auth.Claims, error) {
	return auth.Verify(a.cfg.JWTKey, strings.TrimSpace(strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")))
}
func (a *app) authed(h router.HandlerFunc) router.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request, p map[string]string) {
		if _, err := a.claims(r); err != nil {
			httpx.Fail(w, r, 401, "UNAUTHORIZED", "Authentication required")
			return
		}
		h(w, r, p)
	}
}
func (a *app) requirePermission(permission authz.Permission, h router.HandlerFunc) router.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request, p map[string]string) {
		c, err := a.claims(r)
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
func (a *app) createEntry(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	c, _ := a.claims(r)
	var in entryIn
	if !httpx.Decode(w, r, &in) {
		return
	}
	d, err := time.Parse("2006-01-02", in.ActivityDate)
	if err != nil || in.StudentID == "" || in.Surah == "" || in.AyahStart < 1 || in.AyahEnd < in.AyahStart {
		httpx.Fail(w, r, 400, "VALIDATION", "Invalid tahfidz entry")
		return
	}
	types := map[string]bool{"NEW_MEMORIZATION": true, "MURAJAAH": true, "TASMI": true}
	if !types[in.ActivityType] {
		httpx.Fail(w, r, 400, "VALIDATION", "Invalid activity_type")
		return
	}
	id := httpx.NewID()
	tx, err := a.db.BeginTx(r.Context(), nil)
	if err == nil {
		_, err = tx.ExecContext(r.Context(), `INSERT INTO tahfidz_entries(id,student_id,activity_date,surah,ayah_start,ayah_end,juz,page_no,activity_type,score,fluency,tajwid,makhraj,teacher_note,teacher_user_id) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`, id, in.StudentID, d, in.Surah, in.AyahStart, in.AyahEnd, in.Juz, in.Page, in.ActivityType, in.Score, n(in.Fluency), n(in.Tajwid), n(in.Makhraj), n(in.TeacherNote), c.Sub)
	}
	if err == nil {
		err = outbox.Add(r.Context(), tx, "TahfidzEntryCreated", map[string]any{"student_id": in.StudentID, "entry_id": id, "surah": in.Surah, "deep_link": "zabisa://guardian/students/" + in.StudentID + "/tahfidz/" + id})
	}
	if err == nil {
		after := map[string]any{"student_id": in.StudentID, "activity_date": in.ActivityDate, "surah": in.Surah, "ayah_start": in.AyahStart, "ayah_end": in.AyahEnd, "activity_type": in.ActivityType, "verification_status": "VERIFIED"}
		err = auditx.Add(r.Context(), tx, auditx.FromRequest(r, c.Sub, "TAHFIDZ_ENTRY_CREATED", "tahfidz_entry", id, nil, after))
	}
	if err == nil {
		err = tx.Commit()
	} else if tx != nil {
		_ = tx.Rollback()
	}
	if err != nil {
		httpx.Fail(w, r, 500, "SAVE_FAILED", "Could not save tahfidz entry")
		return
	}
	httpx.JSON(w, 201, map[string]string{"id": id})
}
func (a *app) listEntries(w http.ResponseWriter, r *http.Request, p map[string]string) {
	rows, err := a.db.QueryContext(r.Context(), `SELECT id,activity_date,surah,ayah_start,ayah_end,juz,page_no,activity_type,score,fluency,tajwid,makhraj,teacher_note,teacher_user_id,verification_status FROM tahfidz_entries WHERE student_id=? ORDER BY activity_date DESC,created_at DESC LIMIT 200`, p["id"])
	if err != nil {
		httpx.Fail(w, r, 500, "QUERY_FAILED", "Could not load tahfidz")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id, surah, typ, teacher, status string
		var d time.Time
		var a1, a2 int
		var juz, page sql.NullInt64
		var score sql.NullFloat64
		var flu, taj, mak, note sql.NullString
		if rows.Scan(&id, &d, &surah, &a1, &a2, &juz, &page, &typ, &score, &flu, &taj, &mak, &note, &teacher, &status) == nil {
			out = append(out, map[string]any{"id": id, "date": d.Format("2006-01-02"), "surah": surah, "ayah_start": a1, "ayah_end": a2, "juz": nullableInt(juz), "page": nullableInt(page), "activity_type": typ, "score": nullableFloat(score), "fluency": flu.String, "tajwid": taj.String, "makhraj": mak.String, "teacher_note": note.String, "teacher_user_id": teacher, "verification_status": status})
		}
	}
	httpx.JSON(w, 200, out)
}
func n(v string) any {
	if strings.TrimSpace(v) == "" {
		return nil
	}
	return strings.TrimSpace(v)
}
func nullableInt(v sql.NullInt64) any {
	if !v.Valid {
		return nil
	}
	return v.Int64
}
func nullableFloat(v sql.NullFloat64) any {
	if !v.Valid {
		return nil
	}
	return v.Float64
}

func envURL(key, fallback string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return fallback
}
