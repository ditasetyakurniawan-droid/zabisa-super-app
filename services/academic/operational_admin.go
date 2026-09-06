package main

import (
	"database/sql"
	"net/http"
	"strings"

	"github.com/zabisa/platform/packages/go/platform/auditx"
	"github.com/zabisa/platform/packages/go/platform/database"
	"github.com/zabisa/platform/packages/go/platform/httpx"
	"github.com/zabisa/platform/packages/go/platform/outbox"
)

type updateSubjectIn struct {
	Code     string `json:"code"`
	Name     string `json:"name"`
	Category string `json:"category"`
	Active   bool   `json:"active"`
}

func (a *app) listSubjectsAdmin(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	rows, err := a.db.QueryContext(r.Context(), `SELECT id,code,name,category,active FROM subjects ORDER BY active DESC,name`)
	if err != nil {
		httpx.Fail(w, r, http.StatusInternalServerError, "QUERY_FAILED", "Could not load subjects")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id, code, name, category string
		var active bool
		if rows.Scan(&id, &code, &name, &category, &active) == nil {
			out = append(out, map[string]any{"id": id, "code": code, "name": name, "category": category, "active": active})
		}
	}
	httpx.JSON(w, http.StatusOK, out)
}

func (a *app) updateSubject(w http.ResponseWriter, r *http.Request, p map[string]string) {
	actor, _ := a.access.Claims(r)
	var in updateSubjectIn
	if !httpx.Decode(w, r, &in) {
		return
	}
	in.Code = strings.TrimSpace(in.Code)
	in.Name = strings.TrimSpace(in.Name)
	in.Category = strings.ToUpper(strings.TrimSpace(in.Category))
	if in.Code == "" || in.Name == "" || in.Category == "" {
		httpx.Fail(w, r, http.StatusBadRequest, "VALIDATION", "code, name and category are required")
		return
	}
	tx, err := a.db.BeginTx(r.Context(), nil)
	if err != nil {
		httpx.Fail(w, r, 500, "TX_FAILED", "Could not update subject")
		return
	}
	defer tx.Rollback()
	var beforeCode, beforeName, beforeCategory string
	var beforeActive bool
	if err = tx.QueryRowContext(r.Context(), `SELECT code,name,category,active FROM subjects WHERE id=? FOR UPDATE`, p["id"]).Scan(&beforeCode, &beforeName, &beforeCategory, &beforeActive); err == sql.ErrNoRows {
		httpx.Fail(w, r, http.StatusNotFound, "NOT_FOUND", "Subject not found")
		return
	} else if err != nil {
		httpx.Fail(w, r, 500, "QUERY_FAILED", "Could not load subject")
		return
	}
	if _, err = tx.ExecContext(r.Context(), `UPDATE subjects SET code=?,name=?,category=?,active=? WHERE id=?`, in.Code, in.Name, in.Category, in.Active, p["id"]); err != nil {
		httpx.Fail(w, r, http.StatusConflict, "UPDATE_FAILED", "Could not update subject; code may already exist")
		return
	}
	before := map[string]any{"code": beforeCode, "name": beforeName, "category": beforeCategory, "active": beforeActive}
	after := map[string]any{"code": in.Code, "name": in.Name, "category": in.Category, "active": in.Active}
	if err = auditx.Add(r.Context(), tx, auditx.FromRequest(r, actor.Sub, "SUBJECT_UPDATED", "subject", p["id"], before, after)); err != nil {
		httpx.Fail(w, r, 500, "AUDIT_ENQUEUE_FAILED", "Could not audit subject update")
		return
	}
	if err = tx.Commit(); err != nil {
		httpx.Fail(w, r, 500, "COMMIT_FAILED", "Could not update subject")
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"id": p["id"], "active": in.Active})
}

func (a *app) updateGradeDraft(w http.ResponseWriter, r *http.Request, p map[string]string) {
	actor, _ := a.access.Claims(r)
	var in gradeIn
	if !httpx.Decode(w, r, &in) {
		return
	}
	if in.StudentID == "" || in.SubjectID == "" || strings.TrimSpace(in.AcademicYear) == "" || strings.TrimSpace(in.Semester) == "" || strings.TrimSpace(in.AssessmentType) == "" {
		httpx.Fail(w, r, 400, "VALIDATION", "Required grade fields are missing")
		return
	}
	tx, err := a.db.BeginTx(r.Context(), nil)
	if err != nil {
		httpx.Fail(w, r, 500, "TX_FAILED", "Could not update grade draft")
		return
	}
	defer tx.Rollback()
	var beforeStudent, beforeSubject, beforeYear, beforeSemester, beforeType string
	var beforeScore sql.NullFloat64
	var beforeGrade sql.NullString
	var published bool
	if err = tx.QueryRowContext(r.Context(), `SELECT student_id,subject_id,academic_year,semester,assessment_type,score,grade,published FROM grades WHERE id=? FOR UPDATE`, p["id"]).Scan(&beforeStudent, &beforeSubject, &beforeYear, &beforeSemester, &beforeType, &beforeScore, &beforeGrade, &published); err == sql.ErrNoRows {
		httpx.Fail(w, r, 404, "NOT_FOUND", "Grade not found")
		return
	} else if err != nil {
		httpx.Fail(w, r, 500, "QUERY_FAILED", "Could not load grade")
		return
	}
	if published {
		httpx.Fail(w, r, 409, "IMMUTABLE", "Published grade cannot be edited")
		return
	}
	if _, err = tx.ExecContext(r.Context(), `UPDATE grades SET student_id=?,subject_id=?,academic_year=?,semester=?,assessment_type=?,score=?,grade=?,teacher_note=? WHERE id=?`, in.StudentID, in.SubjectID, in.AcademicYear, in.Semester, in.AssessmentType, in.Score, database.NullString(in.Grade), database.NullString(in.TeacherNote), p["id"]); err != nil {
		httpx.Fail(w, r, 500, "UPDATE_FAILED", "Could not update grade draft")
		return
	}
	before := map[string]any{"student_id": beforeStudent, "subject_id": beforeSubject, "academic_year": beforeYear, "semester": beforeSemester, "assessment_type": beforeType, "score": database.NullableFloat(beforeScore), "grade": beforeGrade.String, "published": false}
	after := map[string]any{"student_id": in.StudentID, "subject_id": in.SubjectID, "academic_year": in.AcademicYear, "semester": in.Semester, "assessment_type": in.AssessmentType, "score": in.Score, "grade": strings.TrimSpace(in.Grade), "published": false}
	if err = auditx.Add(r.Context(), tx, auditx.FromRequest(r, actor.Sub, "GRADE_UPDATED", "grade", p["id"], before, after)); err != nil {
		httpx.Fail(w, r, 500, "AUDIT_ENQUEUE_FAILED", "Could not audit grade update")
		return
	}
	if err = tx.Commit(); err != nil {
		httpx.Fail(w, r, 500, "COMMIT_FAILED", "Could not update grade draft")
		return
	}
	httpx.JSON(w, 200, map[string]any{"id": p["id"], "published": false})
}

func (a *app) publishGrade(w http.ResponseWriter, r *http.Request, p map[string]string) {
	tx, err := a.db.BeginTx(r.Context(), nil)
	if err != nil {
		httpx.Fail(w, r, http.StatusInternalServerError, "TX_FAILED", "Could not publish grade")
		return
	}
	defer tx.Rollback()
	var studentID string
	var published bool
	if err = tx.QueryRowContext(r.Context(), `SELECT student_id,published FROM grades WHERE id=? FOR UPDATE`, p["id"]).Scan(&studentID, &published); err == sql.ErrNoRows {
		httpx.Fail(w, r, http.StatusNotFound, "NOT_FOUND", "Grade not found")
		return
	} else if err != nil {
		httpx.Fail(w, r, http.StatusInternalServerError, "QUERY_FAILED", "Could not load grade")
		return
	}
	if published {
		httpx.Fail(w, r, http.StatusConflict, "ALREADY_PUBLISHED", "Grade is already published")
		return
	}
	if _, err = tx.ExecContext(r.Context(), `UPDATE grades SET published=TRUE WHERE id=?`, p["id"]); err == nil {
		err = outbox.Add(r.Context(), tx, "GradePublished", map[string]any{"student_id": studentID, "grade_id": p["id"], "deep_link": "zabisa://guardian/students/" + studentID + "/academic/" + p["id"]})
	}
	if err == nil {
		actor, _ := a.access.Claims(r)
		err = auditx.Add(r.Context(), tx, auditx.FromRequest(r, actor.Sub, "GRADE_PUBLISHED", "grade", p["id"], map[string]any{"published": false}, map[string]any{"published": true, "student_id": studentID}))
	}
	if err == nil {
		err = tx.Commit()
	}
	if err != nil {
		httpx.Fail(w, r, http.StatusInternalServerError, "PUBLISH_FAILED", "Could not publish grade")
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"id": p["id"], "published": true})
}

func (a *app) publishReportWithNotification(w http.ResponseWriter, r *http.Request, p map[string]string) {
	tx, err := a.db.BeginTx(r.Context(), nil)
	if err != nil {
		httpx.Fail(w, r, http.StatusInternalServerError, "TX_FAILED", "Could not publish report")
		return
	}
	defer tx.Rollback()
	var studentID, status string
	if err = tx.QueryRowContext(r.Context(), `SELECT student_id,status FROM reports WHERE id=? FOR UPDATE`, p["id"]).Scan(&studentID, &status); err == sql.ErrNoRows {
		httpx.Fail(w, r, http.StatusNotFound, "NOT_FOUND", "Report not found")
		return
	} else if err != nil {
		httpx.Fail(w, r, http.StatusInternalServerError, "QUERY_FAILED", "Could not load report")
		return
	}
	if status == "PUBLISHED" {
		httpx.Fail(w, r, http.StatusConflict, "ALREADY_PUBLISHED", "Report is already published")
		return
	}
	if _, err = tx.ExecContext(r.Context(), `UPDATE reports SET status='PUBLISHED',published_at=UTC_TIMESTAMP(6) WHERE id=?`, p["id"]); err == nil {
		err = outbox.Add(r.Context(), tx, "ReportPublished", map[string]any{"student_id": studentID, "report_id": p["id"], "deep_link": "zabisa://guardian/students/" + studentID + "/academic/" + p["id"]})
	}
	if err == nil {
		actor, _ := a.access.Claims(r)
		err = auditx.Add(r.Context(), tx, auditx.FromRequest(r, actor.Sub, "REPORT_PUBLISHED", "report", p["id"], map[string]any{"status": status}, map[string]any{"status": "PUBLISHED", "student_id": studentID}))
	}
	if err == nil {
		err = tx.Commit()
	}
	if err != nil {
		httpx.Fail(w, r, http.StatusInternalServerError, "PUBLISH_FAILED", "Could not publish report")
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]string{"status": "PUBLISHED"})
}
