package main

import (
	"context"
	"database/sql"
	"embed"
	"net/http"
	"strings"

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
	service.MustRun(service.Options{Name: "academic-service", Database: "academic_db", Port: 8085, Migrations: migrationFS, Build: buildService})
}

func buildService(ctx context.Context, db *sql.DB, cfg config.Config) (http.Handler, error) {
	a := &app{db: db, cfg: cfg, access: access.Control{JWTKey: cfg.JWTKey, InternalKey: cfg.InternalServiceKey, StudentServiceURL: config.Env("STUDENT_SERVICE_URL", "http://student:8083")}}
	go outbox.Worker{DB: db, Endpoint: config.Env("NOTIFICATION_SERVICE_URL", "http://notification:8087/internal/v1/events"), AuditEndpoint: config.Env("AUDIT_SERVICE_URL", "http://identity:8081/internal/v1/audit-events"), InternalKey: cfg.InternalServiceKey, Service: cfg.Service}.Run(ctx)
	routes := service.Router(db)
	routes.Handle("POST", "/api/v1/admin/subjects", a.access.RequirePermission(authz.AcademicsWrite, a.createSubject))
	routes.Handle("GET", "/api/v1/subjects", a.access.Authenticated(a.listSubjects))
	routes.Handle("GET", "/api/v1/admin/subjects", a.access.RequirePermission(authz.AcademicsRead, a.listSubjectsAdmin))
	routes.Handle("PATCH", "/api/v1/admin/subjects/{id}", a.access.RequirePermission(authz.AcademicsWrite, a.updateSubject))
	routes.Handle("POST", "/api/v1/grades", a.access.RequirePermission(authz.AcademicsWrite, a.createGrade))
	routes.Handle("GET", "/api/v1/students/{id}/grades", a.access.StudentScoped(authz.AcademicsRead, a.listGrades))
	routes.Handle("GET", "/api/v1/admin/grades", a.access.RequirePermission(authz.AcademicsRead, a.listGradesAdmin))
	routes.Handle("PATCH", "/api/v1/admin/grades/{id}", a.access.RequirePermission(authz.AcademicsWrite, a.updateGradeDraft))
	routes.Handle("PATCH", "/api/v1/admin/grades/{id}/publish", a.access.RequirePermission(authz.AcademicsPublish, a.publishGrade))
	routes.Handle("POST", "/api/v1/admin/reports", a.access.RequirePermission(authz.AcademicsWrite, a.createReport))
	routes.Handle("GET", "/api/v1/admin/reports", a.access.RequirePermission(authz.AcademicsRead, a.listReportsAdmin))
	routes.Handle("PATCH", "/api/v1/admin/reports/{id}/publish", a.access.RequirePermission(authz.AcademicsPublish, a.publishReportWithNotification))
	routes.Handle("GET", "/api/v1/students/{id}/reports", a.access.StudentScoped(authz.AcademicsRead, a.listReportsStudent))
	return routes, nil
}
func (a *app) createSubject(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	actor, _ := a.access.Claims(r)
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
	c, _ := a.access.Claims(r)
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
		_, err = tx.ExecContext(r.Context(), `INSERT INTO grades(id,student_id,subject_id,academic_year,semester,assessment_type,score,grade,teacher_note,published,teacher_user_id) VALUES(?,?,?,?,?,?,?,?,?,?,?)`, id, in.StudentID, in.SubjectID, in.AcademicYear, in.Semester, in.AssessmentType, in.Score, database.NullString(in.Grade), database.NullString(in.TeacherNote), in.Published, c.Sub)
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
			out = append(out, map[string]any{"id": id, "subject_code": code, "subject_name": name, "academic_year": year, "semester": semester, "assessment_type": typ, "score": database.NullableFloat(score), "grade": grade.String, "teacher_note": note.String, "created_at": created})
		}
	}
	httpx.JSON(w, 200, out)
}
