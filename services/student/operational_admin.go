package main

import (
	"database/sql"
	"net/http"
	"strings"

	"github.com/zabisa/platform/packages/go/platform/auditx"
	"github.com/zabisa/platform/packages/go/platform/database"
	"github.com/zabisa/platform/packages/go/platform/httpx"
)

type updateStudentIn struct {
	StudentNo    string `json:"student_no"`
	FullName     string `json:"full_name"`
	PhotoURL     string `json:"photo_url"`
	ClassName    string `json:"class_name"`
	ProgramName  string `json:"program_name"`
	AcademicYear string `json:"academic_year"`
	Status       string `json:"status"`
}

func (a *app) updateStudentAdmin(w http.ResponseWriter, r *http.Request, p map[string]string) {
	actor, _ := a.access.Claims(r)
	var in updateStudentIn
	if !httpx.Decode(w, r, &in) {
		return
	}
	in.StudentNo = strings.TrimSpace(in.StudentNo)
	in.FullName = strings.TrimSpace(in.FullName)
	in.Status = strings.ToUpper(strings.TrimSpace(in.Status))
	if in.StudentNo == "" || in.FullName == "" {
		httpx.Fail(w, r, http.StatusBadRequest, "VALIDATION", "student_no and full_name are required")
		return
	}
	if in.Status == "" {
		in.Status = "ACTIVE"
	}
	if !map[string]bool{"ACTIVE": true, "INACTIVE": true, "GRADUATED": true}[in.Status] {
		httpx.Fail(w, r, http.StatusBadRequest, "VALIDATION", "invalid student status")
		return
	}
	tx, err := a.db.BeginTx(r.Context(), nil)
	if err != nil {
		httpx.Fail(w, r, 500, "TX_FAILED", "Could not update student")
		return
	}
	defer tx.Rollback()
	var beforeNo, beforeStatus string
	var beforeClass, beforeProgram, beforeYear sql.NullString
	if err = tx.QueryRowContext(r.Context(), `SELECT student_no,class_name,program_name,academic_year,status FROM students WHERE id=? FOR UPDATE`, p["id"]).Scan(&beforeNo, &beforeClass, &beforeProgram, &beforeYear, &beforeStatus); err == sql.ErrNoRows {
		httpx.Fail(w, r, 404, "NOT_FOUND", "Student not found")
		return
	} else if err != nil {
		httpx.Fail(w, r, 500, "QUERY_FAILED", "Could not load student")
		return
	}
	if _, err = tx.ExecContext(r.Context(), `UPDATE students SET student_no=?,full_name=?,photo_url=?,class_name=?,program_name=?,academic_year=?,status=? WHERE id=?`, in.StudentNo, in.FullName, database.NullString(in.PhotoURL), database.NullString(in.ClassName), database.NullString(in.ProgramName), database.NullString(in.AcademicYear), in.Status, p["id"]); err != nil {
		httpx.Fail(w, r, http.StatusConflict, "UPDATE_FAILED", "Could not update student; student number may already exist")
		return
	}
	before := map[string]any{"student_no": beforeNo, "class_name": beforeClass.String, "program_name": beforeProgram.String, "academic_year": beforeYear.String, "status": beforeStatus}
	after := map[string]any{"student_no": in.StudentNo, "class_name": strings.TrimSpace(in.ClassName), "program_name": strings.TrimSpace(in.ProgramName), "academic_year": strings.TrimSpace(in.AcademicYear), "status": in.Status}
	if err = auditx.Add(r.Context(), tx, auditx.FromRequest(r, actor.Sub, "STUDENT_UPDATED", "student", p["id"], before, after)); err != nil {
		httpx.Fail(w, r, 500, "AUDIT_ENQUEUE_FAILED", "Could not update student audit record")
		return
	}
	if err = tx.Commit(); err != nil {
		httpx.Fail(w, r, 500, "COMMIT_FAILED", "Could not update student")
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"id": p["id"], "status": in.Status})
}

func (a *app) rejectGuardianLinkAdmin(w http.ResponseWriter, r *http.Request, p map[string]string) {
	actor, _ := a.access.Claims(r)
	tx, err := a.db.BeginTx(r.Context(), nil)
	if err != nil {
		httpx.Fail(w, r, 500, "TX_FAILED", "Could not update guardian link")
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
		httpx.Fail(w, r, 409, "INVALID_STATE", "Guardian link state does not allow this transition")
		return
	}
	if _, err = tx.ExecContext(r.Context(), `UPDATE guardian_relationships SET status='REJECTED' WHERE id=?`, p["id"]); err != nil {
		httpx.Fail(w, r, 500, "UPDATE_FAILED", "Could not update guardian link")
		return
	}
	before := map[string]any{"status": status, "relationship": relationship, "guardian_user_id": guardianID, "student_id": studentID}
	after := map[string]any{"status": "REJECTED", "relationship": relationship, "guardian_user_id": guardianID, "student_id": studentID}
	if err = auditx.Add(r.Context(), tx, auditx.FromRequest(r, actor.Sub, "GUARDIAN_LINK_REJECTED", "guardian_relationship", p["id"], before, after)); err != nil {
		httpx.Fail(w, r, 500, "AUDIT_ENQUEUE_FAILED", "Could not audit guardian relationship")
		return
	}
	if err = tx.Commit(); err != nil {
		httpx.Fail(w, r, 500, "COMMIT_FAILED", "Could not update guardian link")
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]string{"status": "REJECTED"})
}

func (a *app) revokeGuardianLinkAdmin(w http.ResponseWriter, r *http.Request, p map[string]string) {
	actor, _ := a.access.Claims(r)
	tx, err := a.db.BeginTx(r.Context(), nil)
	if err != nil {
		httpx.Fail(w, r, 500, "TX_FAILED", "Could not update guardian link")
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
	if status != "APPROVED" {
		httpx.Fail(w, r, 409, "INVALID_STATE", "Guardian link state does not allow this transition")
		return
	}
	if _, err = tx.ExecContext(r.Context(), `UPDATE guardian_relationships SET status='REVOKED' WHERE id=?`, p["id"]); err != nil {
		httpx.Fail(w, r, 500, "UPDATE_FAILED", "Could not update guardian link")
		return
	}
	before := map[string]any{"status": status, "relationship": relationship, "guardian_user_id": guardianID, "student_id": studentID}
	after := map[string]any{"status": "REVOKED", "relationship": relationship, "guardian_user_id": guardianID, "student_id": studentID}
	if err = auditx.Add(r.Context(), tx, auditx.FromRequest(r, actor.Sub, "GUARDIAN_LINK_REVOKED", "guardian_relationship", p["id"], before, after)); err != nil {
		httpx.Fail(w, r, 500, "AUDIT_ENQUEUE_FAILED", "Could not audit guardian relationship")
		return
	}
	if err = tx.Commit(); err != nil {
		httpx.Fail(w, r, 500, "COMMIT_FAILED", "Could not update guardian link")
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]string{"status": "REVOKED"})
}
