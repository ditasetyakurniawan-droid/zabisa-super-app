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
)

//go:embed migrations/*.sql
var migrationFS embed.FS

type app struct {
	db  *sql.DB
	cfg config.Config
}
type subjectIn struct {
	Code     string `json:"code"`
	Name     string `json:"name"`
	Category string `json:"category"`
}
type gradeIn struct {
	StudentID      string   `json:"student_id"`
	SubjectID      string   `json:"subject_id"`
	AcademicYear   string   `json:"academic_year"`
	Semester       string   `json:"semester"`
	AssessmentType string   `json:"assessment_type"`
	Score          *float64 `json:"score"`
	Grade          string   `json:"grade"`
	TeacherNote    string   `json:"teacher_note"`
	Published      bool     `json:"published"`
}

func main() {
	cfg := config.Load("academic-service", "academic_db", 8085)
	if err := cfg.ValidateRuntime(true); err != nil {
		slog.Error("invalid config", "error", err)
		os.Exit(1)
	}
	db, err := database.Open(context.Background(), cfg.DSN(), database.TLSOptions{Mode: cfg.MySQLTLSMode, CAFile: cfg.MySQLTLSCAFile, ServerName: cfg.MySQLTLSServerName})
	if err != nil {
		panic(err)
	}
	defer db.Close()
	if cfg.ShouldMigrate() {
		if err = migrate.Apply(context.Background(), db, migrationFS, "migrations"); err != nil {
			panic(err)
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
	rt.Handle("POST", "/api/v1/admin/subjects", a.requirePermission(authz.AcademicsWrite, a.createSubject))
	rt.Handle("GET", "/api/v1/subjects", a.authed(a.listSubjects))
	rt.Handle("GET", "/api/v1/admin/subjects", a.requirePermission(authz.AcademicsRead, a.listSubjectsAdmin))
	rt.Handle("PATCH", "/api/v1/admin/subjects/{id}", a.requirePermission(authz.AcademicsWrite, a.updateSubject))
	rt.Handle("POST", "/api/v1/grades", a.requirePermission(authz.AcademicsWrite, a.createGrade))
	rt.Handle("GET", "/api/v1/students/{id}/grades", a.studentScoped(authz.AcademicsRead, a.listGrades))
	rt.Handle("GET", "/api/v1/admin/grades", a.requirePermission(authz.AcademicsRead, a.listGradesAdmin))
	rt.Handle("PATCH", "/api/v1/admin/grades/{id}", a.requirePermission(authz.AcademicsWrite, a.updateGradeDraft))
	rt.Handle("PATCH", "/api/v1/admin/grades/{id}/publish", a.requirePermission(authz.AcademicsPublish, a.publishGrade))
	rt.Handle("POST", "/api/v1/admin/reports", a.requirePermission(authz.AcademicsWrite, a.createReport))
	rt.Handle("GET", "/api/v1/admin/reports", a.requirePermission(authz.AcademicsRead, a.listReportsAdmin))
	rt.Handle("PATCH", "/api/v1/admin/reports/{id}/publish", a.requirePermission(authz.AcademicsPublish, a.publishReportWithNotification))
	rt.Handle("GET", "/api/v1/students/{id}/reports", a.studentScoped(authz.AcademicsRead, a.listReportsStudent))
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
func (a *app) createSubject(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	actor, _ := a.claims(r)
	var in subjectIn
	if !httpx.Decode(w, r, &in) {
		return
	}
	in.Code = strings.TrimSpace(in.Code)
	in.Name = strings.TrimSpace(in.Name)
	in.Category = strings.ToUpper(strings.TrimSpace(in.Category))
	if in.Code == "" || in.Name == "" || in.Category == "" {
		httpx.Fail(w, r, 400, "VALIDATION", "code, name and category are required")
		return
	}
	id := httpx.NewID()
	tx, err := a.db.BeginTx(r.Context(), nil)
	if err != nil {
		httpx.Fail(w, r, 500, "TX_FAILED", "Could not create subject")
		return
	}
	defer tx.Rollback()
	if _, err = tx.ExecContext(r.Context(), `INSERT INTO subjects(id,code,name,category) VALUES(?,?,?,?)`, id, in.Code, in.Name, in.Category); err != nil {
		httpx.Fail(w, r, 409, "CREATE_FAILED", "Could not create subject")
		return
	}
	after := map[string]any{"code": in.Code, "name": in.Name, "category": in.Category, "active": true}
	if err = auditx.Add(r.Context(), tx, auditx.FromRequest(r, actor.Sub, "SUBJECT_CREATED", "subject", id, nil, after)); err != nil {
		httpx.Fail(w, r, 500, "AUDIT_ENQUEUE_FAILED", "Could not audit subject creation")
		return
	}
	if err = tx.Commit(); err != nil {
		httpx.Fail(w, r, 500, "COMMIT_FAILED", "Could not create subject")
		return
	}
	httpx.JSON(w, 201, map[string]string{"id": id})
}
func (a *app) listSubjects(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	rows, err := a.db.QueryContext(r.Context(), `SELECT id,code,name,category FROM subjects WHERE active=TRUE ORDER BY name`)
	if err != nil {
		httpx.Fail(w, r, 500, "QUERY_FAILED", "Could not load subjects")
		return
	}
	defer rows.Close()
	out := []map[string]string{}
	for rows.Next() {
		var id, code, name, cat string
		if rows.Scan(&id, &code, &name, &cat) == nil {
			out = append(out, map[string]string{"id": id, "code": code, "name": name, "category": cat})
		}
	}
	httpx.JSON(w, 200, out)
}
func (a *app) createGrade(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	c, _ := a.claims(r)
	var in gradeIn
	if !httpx.Decode(w, r, &in) {
		return
	}
	if in.StudentID == "" || in.SubjectID == "" || in.AcademicYear == "" || in.Semester == "" || in.AssessmentType == "" {
		httpx.Fail(w, r, 400, "VALIDATION", "Required grade fields are missing")
		return
	}
	id := httpx.NewID()
	tx, err := a.db.BeginTx(r.Context(), nil)
	if err == nil {
		_, err = tx.ExecContext(r.Context(), `INSERT INTO grades(id,student_id,subject_id,academic_year,semester,assessment_type,score,grade,teacher_note,published,teacher_user_id) VALUES(?,?,?,?,?,?,?,?,?,?,?)`, id, in.StudentID, in.SubjectID, in.AcademicYear, in.Semester, in.AssessmentType, in.Score, n(in.Grade), n(in.TeacherNote), in.Published, c.Sub)
	}
	if err == nil && in.Published {
		err = outbox.Add(r.Context(), tx, "GradePublished", map[string]any{"student_id": in.StudentID, "grade_id": id, "deep_link": "zabisa://guardian/students/" + in.StudentID + "/academic/" + id})
	}
	if err == nil {
		after := map[string]any{"student_id": in.StudentID, "subject_id": in.SubjectID, "academic_year": in.AcademicYear, "semester": in.Semester, "assessment_type": in.AssessmentType, "score": in.Score, "grade": strings.TrimSpace(in.Grade), "published": in.Published}
		err = auditx.Add(r.Context(), tx, auditx.FromRequest(r, c.Sub, "GRADE_CREATED", "grade", id, nil, after))
	}
	if err == nil {
		err = tx.Commit()
	} else if tx != nil {
		_ = tx.Rollback()
	}
	if err != nil {
		httpx.Fail(w, r, 500, "SAVE_FAILED", "Could not save grade")
		return
	}
	httpx.JSON(w, 201, map[string]any{"id": id, "published": in.Published})
}
func (a *app) listGrades(w http.ResponseWriter, r *http.Request, p map[string]string) {
	rows, err := a.db.QueryContext(r.Context(), `SELECT g.id,s.code,s.name,g.academic_year,g.semester,g.assessment_type,g.score,g.grade,g.teacher_note,g.created_at FROM grades g JOIN subjects s ON s.id=g.subject_id WHERE g.student_id=? AND g.published=TRUE ORDER BY g.created_at DESC LIMIT 200`, p["id"])
	if err != nil {
		httpx.Fail(w, r, 500, "QUERY_FAILED", "Could not load grades")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id, code, name, year, semester, typ string
		var score sql.NullFloat64
		var grade, note sql.NullString
		var created any
		if rows.Scan(&id, &code, &name, &year, &semester, &typ, &score, &grade, &note, &created) == nil {
			out = append(out, map[string]any{"id": id, "subject_code": code, "subject_name": name, "academic_year": year, "semester": semester, "assessment_type": typ, "score": nullableFloat(score), "grade": grade.String, "teacher_note": note.String, "created_at": created})
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
