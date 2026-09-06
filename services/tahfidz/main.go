package main

import (
	"context"
	"database/sql"
	"embed"
	"net/http"
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
	service.MustRun(service.Options{Name: "tahfidz-service", Database: "tahfidz_db", Port: 8084, Migrations: migrationFS, Build: buildService})
}

func buildService(ctx context.Context, db *sql.DB, cfg config.Config) (http.Handler, error) {
	a := &app{db: db, cfg: cfg, access: access.Control{JWTKey: cfg.JWTKey, InternalKey: cfg.InternalServiceKey, StudentServiceURL: config.Env("STUDENT_SERVICE_URL", "http://student:8083")}}
	go outbox.Worker{DB: db, Endpoint: config.Env("NOTIFICATION_SERVICE_URL", "http://notification:8087/internal/v1/events"), AuditEndpoint: config.Env("AUDIT_SERVICE_URL", "http://identity:8081/internal/v1/audit-events"), InternalKey: cfg.InternalServiceKey, Service: cfg.Service}.Run(ctx)
	routes := service.Router(db)
	routes.Handle("POST", "/api/v1/tahfidz/entries", a.access.RequirePermission(authz.TahfidzWrite, a.createEntry))
	routes.Handle("GET", "/api/v1/tahfidz/entries", a.access.RequirePermission(authz.TahfidzRead, a.listEntriesAdmin))
	routes.Handle("POST", "/api/v1/tahfidz/targets", a.access.RequirePermission(authz.TahfidzWrite, a.createTarget))
	routes.Handle("GET", "/api/v1/tahfidz/targets", a.access.RequirePermission(authz.TahfidzRead, a.listTargets))
	routes.Handle("PATCH", "/api/v1/tahfidz/targets/{id}", a.access.RequirePermission(authz.TahfidzWrite, a.updateTarget))
	routes.Handle("GET", "/api/v1/tahfidz/students/{id}/entries", a.access.StudentScoped(authz.TahfidzRead, a.listEntries))
	return routes, nil
}
func (a *app) createEntry(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	c, _ := a.access.Claims(r)
	var in entryIn
	if !httpx.Decode(w, r, &in) {
		return
	}
	d, err := time.Parse(dateLayout, in.ActivityDate)
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
		_, err = tx.ExecContext(r.Context(), `INSERT INTO tahfidz_entries(id,student_id,activity_date,surah,ayah_start,ayah_end,juz,page_no,activity_type,score,fluency,tajwid,makhraj,teacher_note,teacher_user_id) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`, id, in.StudentID, d, in.Surah, in.AyahStart, in.AyahEnd, in.Juz, in.Page, in.ActivityType, in.Score, database.NullString(in.Fluency), database.NullString(in.Tajwid), database.NullString(in.Makhraj), database.NullString(in.TeacherNote), c.Sub)
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
			out = append(out, map[string]any{"id": id, "date": d.Format(dateLayout), "surah": surah, "ayah_start": a1, "ayah_end": a2, "juz": database.NullableInt(juz), "page": database.NullableInt(page), "activity_type": typ, "score": database.NullableFloat(score), "fluency": flu.String, "tajwid": taj.String, "makhraj": mak.String, "teacher_note": note.String, "teacher_user_id": teacher, "verification_status": status})
		}
	}
	httpx.JSON(w, 200, out)
}
