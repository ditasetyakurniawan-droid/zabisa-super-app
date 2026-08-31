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
type studentIn struct {
	StudentNo    string `json:"student_no"`
	FullName     string `json:"full_name"`
	PhotoURL     string `json:"photo_url"`
	ClassName    string `json:"class_name"`
	ProgramName  string `json:"program_name"`
	AcademicYear string `json:"academic_year"`
	Status       string `json:"status"`
}
type linkIn struct {
	StudentID    string `json:"student_id"`
	Relationship string `json:"relationship"`
}
type attendanceIn struct {
	StudentID string `json:"student_id"`
	Date      string `json:"date"`
	Status    string `json:"status"`
	Note      string `json:"note"`
}

func main() {
	cfg := config.Load("student-service", "student_db", 8083)
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
	go outbox.Worker{DB: db, AuditEndpoint: envURL("AUDIT_SERVICE_URL", "http://identity:8081/internal/v1/audit-events"), InternalKey: cfg.InternalServiceKey, Service: cfg.Service}.Run(ctx)
	if cfg.Environment == "local" {
		if err = a.seedLocal(context.Background()); err != nil {
			slog.Error("seed", "error", err)
			os.Exit(1)
		}
	}
	rt := router.New()
	rt.Handle("GET", "/health/live", health.Live)
	rt.Handle("GET", "/health/ready", health.Ready(db))
	rt.Handle("POST", "/api/v1/admin/students", a.requirePermission(authz.StudentsWrite, a.createStudent))
	rt.Handle("GET", "/api/v1/admin/students", a.requirePermission(authz.StudentsRead, a.listStudentsAdmin))
	rt.Handle("PATCH", "/api/v1/admin/students/{id}", a.requirePermission(authz.StudentsWrite, a.updateStudentAdmin))
	rt.Handle("GET", "/api/v1/admin/guardian-links", a.requirePermission(authz.GuardiansRead, a.listGuardianLinksAdmin))
	rt.Handle("POST", "/api/v1/admin/guardian-links", a.requirePermission(authz.GuardiansWrite, a.createGuardianLinkAdmin))
	rt.Handle("GET", "/api/v1/admin/attendance", a.requirePermission(authz.AttendanceRead, a.listAttendanceAdmin))
	rt.Handle("POST", "/api/v1/guardian/links", a.authed(a.requestLink))
	rt.Handle("PATCH", "/api/v1/admin/guardian-links/{id}/approve", a.requirePermission(authz.GuardiansWrite, a.approveLink))
	rt.Handle("PATCH", "/api/v1/admin/guardian-links/{id}/reject", a.requirePermission(authz.GuardiansWrite, a.rejectGuardianLinkAdmin))
	rt.Handle("PATCH", "/api/v1/admin/guardian-links/{id}/revoke", a.requirePermission(authz.GuardiansWrite, a.revokeGuardianLinkAdmin))
	rt.Handle("GET", "/api/v1/guardian/students", a.authed(a.guardianStudents))
	rt.Handle("POST", "/api/v1/admin/attendance", a.requirePermission(authz.AttendanceWrite, a.recordAttendance))
	rt.Handle("GET", "/internal/v1/students/{id}/guardians", a.internal(a.internalGuardians))
	rt.Handle("GET", "/api/v1/guardian/students/{id}/attendance", a.authed(a.guardianAttendance))
	if err = server.Run(cfg.Port, httpx.Middleware(cfg.Service, cfg.AllowedOrigins, rt)); err != nil {
		slog.Error("server", "error", err)
		os.Exit(1)
	}
}
func (a *app) claims(r *http.Request) (auth.Claims, error) {
	raw := strings.TrimSpace(strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer "))
	return auth.Verify(a.cfg.JWTKey, raw)
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
func (a *app) createStudent(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	actor, _ := a.claims(r)
	var in studentIn
	if !httpx.Decode(w, r, &in) {
		return
	}
	in.StudentNo = strings.TrimSpace(in.StudentNo)
	in.FullName = strings.TrimSpace(in.FullName)
	in.PhotoURL = strings.TrimSpace(in.PhotoURL)
	in.ClassName = strings.TrimSpace(in.ClassName)
	in.ProgramName = strings.TrimSpace(in.ProgramName)
	in.AcademicYear = strings.TrimSpace(in.AcademicYear)
	in.Status = strings.ToUpper(strings.TrimSpace(in.Status))
	if in.StudentNo == "" || in.FullName == "" {
		httpx.Fail(w, r, 400, "VALIDATION", "student_no and full_name are required")
		return
	}
	if in.Status == "" {
		in.Status = "ACTIVE"
	}
	if !map[string]bool{"ACTIVE": true, "INACTIVE": true, "GRADUATED": true}[in.Status] {
		httpx.Fail(w, r, 400, "VALIDATION", "invalid student status")
		return
	}
	id := httpx.NewID()
	tx, err := a.db.BeginTx(r.Context(), nil)
	if err != nil {
		httpx.Fail(w, r, 500, "TX_FAILED", "Could not create student")
		return
	}
	defer tx.Rollback()
	if _, err = tx.ExecContext(r.Context(), `INSERT INTO students(id,student_no,full_name,photo_url,class_name,program_name,academic_year,status) VALUES(?,?,?,?,?,?,?,?)`, id, in.StudentNo, in.FullName, n(in.PhotoURL), n(in.ClassName), n(in.ProgramName), n(in.AcademicYear), in.Status); err != nil {
		httpx.Fail(w, r, 409, "STUDENT_CREATE_CONFLICT", "Nomor santri sudah digunakan atau data tidak dapat disimpan")
		return
	}
	after := map[string]any{"student_no": in.StudentNo, "full_name": in.FullName, "photo_url": in.PhotoURL, "class_name": in.ClassName, "program_name": in.ProgramName, "academic_year": in.AcademicYear, "status": in.Status}
	if err = auditx.Add(r.Context(), tx, auditx.FromRequest(r, actor.Sub, "STUDENT_CREATED", "student", id, nil, after)); err != nil {
		httpx.Fail(w, r, 500, "AUDIT_ENQUEUE_FAILED", "Could not create student audit record")
		return
	}
	if err = tx.Commit(); err != nil {
		httpx.Fail(w, r, 500, "COMMIT_FAILED", "Could not create student")
		return
	}
	httpx.JSON(w, 201, map[string]string{"id": id})
}
func (a *app) requestLink(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	c, _ := a.claims(r)
	if c.Role != "GUARDIAN" && c.Role != "WALI_SANTRI" {
		httpx.Fail(w, r, 403, "FORBIDDEN", "Only guardian accounts can request student linking")
		return
	}
	var in linkIn
	if !httpx.Decode(w, r, &in) {
		return
	}
	in.StudentID = strings.TrimSpace(in.StudentID)
	in.Relationship = strings.ToUpper(strings.TrimSpace(in.Relationship))
	allowed := map[string]bool{"FATHER": true, "MOTHER": true, "GUARDIAN": true, "OTHER": true, "APPROVED_GUARDIAN": true}
	if in.StudentID == "" || !allowed[in.Relationship] {
		httpx.Fail(w, r, 400, "VALIDATION", "student_id and valid relationship are required")
		return
	}
	tx, err := a.db.BeginTx(r.Context(), nil)
	if err != nil {
		httpx.Fail(w, r, 500, "TX_FAILED", "Could not request guardian link")
		return
	}
	defer tx.Rollback()
	var studentExists int
	if err = tx.QueryRowContext(r.Context(), `SELECT COUNT(*) FROM students WHERE id=?`, in.StudentID).Scan(&studentExists); err != nil {
		httpx.Fail(w, r, 500, "QUERY_FAILED", "Could not validate student")
		return
	}
	if studentExists == 0 {
		httpx.Fail(w, r, 404, "STUDENT_NOT_FOUND", "Student not found")
		return
	}
	var id, beforeStatus, beforeRelationship string
	err = tx.QueryRowContext(r.Context(), `SELECT id,status,relationship FROM guardian_relationships WHERE guardian_user_id=? AND student_id=? FOR UPDATE`, c.Sub, in.StudentID).Scan(&id, &beforeStatus, &beforeRelationship)
	var before any
	if err == nil {
		switch beforeStatus {
		case "APPROVED":
			httpx.Fail(w, r, 409, "LINK_ALREADY_APPROVED", "Guardian relationship is already approved")
			return
		case "PENDING":
			httpx.Fail(w, r, 409, "LINK_PENDING", "Guardian relationship is already pending approval")
			return
		case "REVOKED", "REJECTED":
			before = map[string]any{"status": beforeStatus, "relationship": beforeRelationship, "guardian_user_id": c.Sub, "student_id": in.StudentID}
			if _, err = tx.ExecContext(r.Context(), `UPDATE guardian_relationships SET relationship=?,status='PENDING',approved_by=NULL,approved_at=NULL WHERE id=?`, in.Relationship, id); err != nil {
				httpx.Fail(w, r, 500, "UPDATE_FAILED", "Could not re-request guardian relationship")
				return
			}
		default:
			httpx.Fail(w, r, 409, "INVALID_LINK_STATE", "Guardian relationship state does not allow a new request")
			return
		}
	} else if err == sql.ErrNoRows {
		id = httpx.NewID()
		if _, err = tx.ExecContext(r.Context(), `INSERT INTO guardian_relationships(id,guardian_user_id,student_id,relationship) VALUES(?,?,?,?)`, id, c.Sub, in.StudentID, in.Relationship); err != nil {
			httpx.Fail(w, r, 409, "CREATE_FAILED", "Could not request guardian relationship")
			return
		}
	} else {
		httpx.Fail(w, r, 500, "QUERY_FAILED", "Could not validate guardian relationship")
		return
	}
	after := map[string]any{"status": "PENDING", "relationship": in.Relationship, "guardian_user_id": c.Sub, "student_id": in.StudentID}
	if err = auditx.Add(r.Context(), tx, auditx.FromRequest(r, c.Sub, "GUARDIAN_LINK_REQUESTED", "guardian_relationship", id, before, after)); err != nil {
		httpx.Fail(w, r, 500, "AUDIT_ENQUEUE_FAILED", "Could not audit guardian link request")
		return
	}
	if err = tx.Commit(); err != nil {
		httpx.Fail(w, r, 500, "COMMIT_FAILED", "Could not request guardian link")
		return
	}
	httpx.JSON(w, 201, map[string]any{"id": id, "status": "PENDING", "re_requested": before != nil})
}
func (a *app) approveLink(w http.ResponseWriter, r *http.Request, p map[string]string) {
	actor, _ := a.claims(r)
	tx, err := a.db.BeginTx(r.Context(), nil)
	if err != nil {
		httpx.Fail(w, r, 500, "TX_FAILED", "Could not approve link")
		return
	}
	defer tx.Rollback()
	var guardianID, studentID, relationship, status string
	if err = tx.QueryRowContext(r.Context(), `SELECT guardian_user_id,student_id,relationship,status FROM guardian_relationships WHERE id=? FOR UPDATE`, p["id"]).Scan(&guardianID, &studentID, &relationship, &status); err == sql.ErrNoRows {
		httpx.Fail(w, r, 404, "NOT_FOUND", "Guardian link not found")
		return
	} else if err != nil {
		httpx.Fail(w, r, 500, "QUERY_FAILED", "Could not load guardian link")
		return
	}
	if status != "PENDING" {
		httpx.Fail(w, r, 409, "INVALID_STATE", "Guardian link is not pending")
		return
	}
	if _, err = tx.ExecContext(r.Context(), `UPDATE guardian_relationships SET status='APPROVED',approved_by=?,approved_at=UTC_TIMESTAMP(6) WHERE id=?`, actor.Sub, p["id"]); err != nil {
		httpx.Fail(w, r, 500, "UPDATE_FAILED", "Could not approve link")
		return
	}
	before := map[string]any{"status": status, "relationship": relationship, "guardian_user_id": guardianID, "student_id": studentID}
	after := map[string]any{"status": "APPROVED", "relationship": relationship, "guardian_user_id": guardianID, "student_id": studentID}
	if err = auditx.Add(r.Context(), tx, auditx.FromRequest(r, actor.Sub, "GUARDIAN_LINK_APPROVED", "guardian_relationship", p["id"], before, after)); err != nil {
		httpx.Fail(w, r, 500, "AUDIT_ENQUEUE_FAILED", "Could not audit guardian approval")
		return
	}
	if err = tx.Commit(); err != nil {
		httpx.Fail(w, r, 500, "COMMIT_FAILED", "Could not approve link")
		return
	}
	httpx.JSON(w, 200, map[string]string{"status": "APPROVED"})
}
func (a *app) guardianStudents(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	c, _ := a.claims(r)
	rows, err := a.db.QueryContext(r.Context(), `SELECT s.id,s.student_no,s.full_name,s.class_name,s.program_name,s.academic_year,s.status FROM guardian_relationships g JOIN students s ON s.id=g.student_id WHERE g.guardian_user_id=? AND g.status='APPROVED' ORDER BY s.full_name`, c.Sub)
	if err != nil {
		httpx.Fail(w, r, 500, "QUERY_FAILED", "Could not load students")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id, no, name, status string
		var class, program, year sql.NullString
		if rows.Scan(&id, &no, &name, &class, &program, &year, &status) == nil {
			out = append(out, map[string]any{"id": id, "student_no": no, "full_name": name, "class_name": class.String, "program_name": program.String, "academic_year": year.String, "status": status})
		}
	}
	httpx.JSON(w, 200, out)
}
func (a *app) recordAttendance(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	c, _ := a.claims(r)
	var in attendanceIn
	if !httpx.Decode(w, r, &in) {
		return
	}
	in.StudentID = strings.TrimSpace(in.StudentID)
	in.Status = strings.ToUpper(strings.TrimSpace(in.Status))
	in.Note = strings.TrimSpace(in.Note)
	d, err := time.Parse("2006-01-02", in.Date)
	if err != nil || in.StudentID == "" {
		httpx.Fail(w, r, 400, "VALIDATION", "student_id and date YYYY-MM-DD are required")
		return
	}
	allowed := map[string]bool{"PRESENT": true, "SICK": true, "PERMITTED": true, "ABSENT": true, "OTHER": true}
	if !allowed[in.Status] {
		httpx.Fail(w, r, 400, "VALIDATION", "invalid attendance status")
		return
	}
	tx, err := a.db.BeginTx(r.Context(), nil)
	if err != nil {
		httpx.Fail(w, r, 500, "TX_FAILED", "Could not save attendance")
		return
	}
	defer tx.Rollback()
	var existingID, beforeStatus string
	var beforeNote sql.NullString
	lookupErr := tx.QueryRowContext(r.Context(), `SELECT id,status,note FROM attendance WHERE student_id=? AND attendance_date=? FOR UPDATE`, in.StudentID, d).Scan(&existingID, &beforeStatus, &beforeNote)
	id := existingID
	if lookupErr == sql.ErrNoRows {
		id = httpx.NewID()
	} else if lookupErr != nil {
		httpx.Fail(w, r, 500, "QUERY_FAILED", "Could not load attendance state")
		return
	}
	if _, err = tx.ExecContext(r.Context(), `INSERT INTO attendance(id,student_id,attendance_date,status,note,recorded_by) VALUES(?,?,?,?,?,?) ON DUPLICATE KEY UPDATE status=VALUES(status),note=VALUES(note),recorded_by=VALUES(recorded_by)`, id, in.StudentID, d, in.Status, n(in.Note), c.Sub); err != nil {
		httpx.Fail(w, r, 500, "SAVE_FAILED", "Could not save attendance")
		return
	}
	var before any
	if lookupErr == nil {
		before = map[string]any{"student_id": in.StudentID, "date": in.Date, "status": beforeStatus, "note": beforeNote.String}
	}
	after := map[string]any{"student_id": in.StudentID, "date": in.Date, "status": in.Status, "note": in.Note}
	if err = auditx.Add(r.Context(), tx, auditx.FromRequest(r, c.Sub, "ATTENDANCE_UPSERTED", "attendance", id, before, after)); err != nil {
		httpx.Fail(w, r, 500, "AUDIT_ENQUEUE_FAILED", "Could not audit attendance")
		return
	}
	if err = tx.Commit(); err != nil {
		httpx.Fail(w, r, 500, "COMMIT_FAILED", "Could not save attendance")
		return
	}
	httpx.JSON(w, 200, map[string]string{"id": id, "status": "SAVED"})
}
func (a *app) guardianAttendance(w http.ResponseWriter, r *http.Request, p map[string]string) {
	c, _ := a.claims(r)
	var ok int
	if err := a.db.QueryRowContext(r.Context(), `SELECT COUNT(*) FROM guardian_relationships WHERE guardian_user_id=? AND student_id=? AND status='APPROVED'`, c.Sub, p["id"]).Scan(&ok); err != nil || ok == 0 {
		httpx.Fail(w, r, 403, "FORBIDDEN", "Student is not linked to this guardian")
		return
	}
	rows, err := a.db.QueryContext(r.Context(), `SELECT attendance_date,status,note FROM attendance WHERE student_id=? ORDER BY attendance_date DESC LIMIT 180`, p["id"])
	if err != nil {
		httpx.Fail(w, r, 500, "QUERY_FAILED", "Could not load attendance")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var d time.Time
		var s string
		var note sql.NullString
		if rows.Scan(&d, &s, &note) == nil {
			out = append(out, map[string]any{"date": d.Format("2006-01-02"), "status": s, "note": note.String})
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

func (a *app) internal(h router.HandlerFunc) router.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request, p map[string]string) {
		if a.cfg.InternalServiceKey == "" || r.Header.Get("X-Internal-Key") != a.cfg.InternalServiceKey {
			httpx.Fail(w, r, http.StatusForbidden, "FORBIDDEN", "Invalid service credential")
			return
		}
		h(w, r, p)
	}
}

func (a *app) internalGuardians(w http.ResponseWriter, r *http.Request, p map[string]string) {
	rows, err := a.db.QueryContext(r.Context(), `SELECT guardian_user_id FROM guardian_relationships WHERE student_id=? AND status='APPROVED'`, p["id"])
	if err != nil {
		httpx.Fail(w, r, 500, "QUERY_FAILED", "Could not resolve guardians")
		return
	}
	defer rows.Close()
	ids := []string{}
	for rows.Next() {
		var id string
		if rows.Scan(&id) == nil {
			ids = append(ids, id)
		}
	}
	httpx.JSON(w, 200, map[string]any{"guardian_user_ids": ids})
}

func envURL(key, fallback string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return fallback
}
