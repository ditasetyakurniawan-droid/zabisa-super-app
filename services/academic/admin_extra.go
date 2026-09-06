package main

import (
	"database/sql"
	"net/http"
	"strings"
	"time"

	"github.com/zabisa/platform/packages/go/platform/auditx"
	"github.com/zabisa/platform/packages/go/platform/database"
	"github.com/zabisa/platform/packages/go/platform/httpx"
)

type reportIn struct {
	StudentID    string `json:"student_id"`
	AcademicYear string `json:"academic_year"`
	Semester     string `json:"semester"`
	ReportType   string `json:"report_type"`
}

func (a *app) listGradesAdmin(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	sid := strings.TrimSpace(r.URL.Query().Get("student_id"))
	rows, err := a.db.QueryContext(r.Context(), `SELECT g.id,g.student_id,s.id,s.code,s.name,g.academic_year,g.semester,g.assessment_type,g.score,g.grade,g.teacher_note,g.published,g.teacher_user_id,g.created_at FROM grades g JOIN subjects s ON s.id=g.subject_id WHERE (?='' OR g.student_id=?) ORDER BY g.created_at DESC LIMIT 500`, sid, sid)
	if err != nil {
		httpx.Fail(w, r, 500, "QUERY_FAILED", "Could not load grades")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id, student, subjectID, code, name, year, semester, typ, teacher string
		var score sql.NullFloat64
		var grade, note sql.NullString
		var published bool
		var created time.Time
		if rows.Scan(&id, &student, &subjectID, &code, &name, &year, &semester, &typ, &score, &grade, &note, &published, &teacher, &created) == nil {
			out = append(out, map[string]any{"id": id, "student_id": student, "subject_id": subjectID, "subject_code": code, "subject_name": name, "academic_year": year, "semester": semester, "assessment_type": typ, "score": database.NullableFloat(score), "grade": grade.String, "teacher_note": note.String, "published": published, "teacher_user_id": teacher, "created_at": created})
		}
	}
	httpx.JSON(w, 200, out)
}

func (a *app) createReport(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	actor, _ := a.access.Claims(r)
	var in reportIn
	if !httpx.Decode(w, r, &in) {
		return
	}
	in.StudentID = strings.TrimSpace(in.StudentID)
	in.AcademicYear = strings.TrimSpace(in.AcademicYear)
	in.Semester = strings.TrimSpace(in.Semester)
	in.ReportType = strings.ToUpper(strings.TrimSpace(in.ReportType))
	if in.StudentID == "" || in.AcademicYear == "" || in.Semester == "" || in.ReportType == "" {
		httpx.Fail(w, r, 400, "VALIDATION", "Required report fields are missing")
		return
	}
	id := httpx.NewID()
	tx, err := a.db.BeginTx(r.Context(), nil)
	if err != nil {
		httpx.Fail(w, r, 500, "TX_FAILED", "Could not create report")
		return
	}
	defer tx.Rollback()
	if _, err = tx.ExecContext(r.Context(), `INSERT INTO reports(id,student_id,academic_year,semester,report_type) VALUES(?,?,?,?,?)`, id, in.StudentID, in.AcademicYear, in.Semester, in.ReportType); err != nil {
		httpx.Fail(w, r, 500, "SAVE_FAILED", "Could not create report")
		return
	}
	after := map[string]any{"student_id": in.StudentID, "academic_year": in.AcademicYear, "semester": in.Semester, "report_type": in.ReportType, "status": "DRAFT"}
	if err = auditx.Add(r.Context(), tx, auditx.FromRequest(r, actor.Sub, "REPORT_CREATED", "report", id, nil, after)); err != nil {
		httpx.Fail(w, r, 500, "AUDIT_ENQUEUE_FAILED", "Could not audit report creation")
		return
	}
	if err = tx.Commit(); err != nil {
		httpx.Fail(w, r, 500, "COMMIT_FAILED", "Could not create report")
		return
	}
	httpx.JSON(w, 201, map[string]any{"id": id, "status": "DRAFT"})
}

func (a *app) publishReport(w http.ResponseWriter, r *http.Request, p map[string]string) {
	res, err := a.db.ExecContext(r.Context(), `UPDATE reports SET status='PUBLISHED',published_at=UTC_TIMESTAMP(6) WHERE id=? AND status<>'PUBLISHED'`, p["id"])
	if err != nil {
		httpx.Fail(w, r, 500, "UPDATE_FAILED", "Could not publish report")
		return
	}
	n, _ := res.RowsAffected()
	if n == 0 {
		httpx.Fail(w, r, 404, "NOT_FOUND", "Report not found or already published")
		return
	}
	httpx.JSON(w, 200, map[string]string{"status": "PUBLISHED"})
}

func (a *app) listReportsAdmin(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	sid := strings.TrimSpace(r.URL.Query().Get("student_id"))
	rows, err := a.db.QueryContext(r.Context(), `SELECT id,student_id,academic_year,semester,report_type,status,pdf_object_key,published_at,created_at FROM reports WHERE (?='' OR student_id=?) ORDER BY created_at DESC LIMIT 500`, sid, sid)
	if err != nil {
		httpx.Fail(w, r, 500, "QUERY_FAILED", "Could not load reports")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id, student, year, semester, typ, status string
		var pdf sql.NullString
		var pub sql.NullTime
		var created time.Time
		if rows.Scan(&id, &student, &year, &semester, &typ, &status, &pdf, &pub, &created) == nil {
			out = append(out, map[string]any{"id": id, "student_id": student, "academic_year": year, "semester": semester, "report_type": typ, "status": status, "pdf_object_key": pdf.String, "published_at": nullableTimeReport(pub), "created_at": created})
		}
	}
	httpx.JSON(w, 200, out)
}

func (a *app) listReportsStudent(w http.ResponseWriter, r *http.Request, p map[string]string) {
	rows, err := a.db.QueryContext(r.Context(), `SELECT id,academic_year,semester,report_type,status,pdf_object_key,published_at FROM reports WHERE student_id=? AND status='PUBLISHED' ORDER BY published_at DESC LIMIT 100`, p["id"])
	if err != nil {
		httpx.Fail(w, r, 500, "QUERY_FAILED", "Could not load reports")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id, year, semester, typ, status string
		var pdf sql.NullString
		var pub sql.NullTime
		if rows.Scan(&id, &year, &semester, &typ, &status, &pdf, &pub) == nil {
			out = append(out, map[string]any{"id": id, "academic_year": year, "semester": semester, "report_type": typ, "status": status, "pdf_object_key": pdf.String, "published_at": nullableTimeReport(pub)})
		}
	}
	httpx.JSON(w, 200, out)
}
func nullableTimeReport(v sql.NullTime) any {
	if !v.Valid {
		return nil
	}
	return v.Time
}
