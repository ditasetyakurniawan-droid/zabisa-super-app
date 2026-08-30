package main

import (
	"context"
	"database/sql"
	"net/http"
	"strings"
	"time"

	"github.com/zabisa/platform/packages/go/platform/auditx"
	"github.com/zabisa/platform/packages/go/platform/httpx"
)

type adminLinkIn struct {
	GuardianUserID string `json:"guardian_user_id"`
	StudentID      string `json:"student_id"`
	Relationship   string `json:"relationship"`
}

func (a *app) seedLocal(ctx context.Context) error {
	const studentID = "00000000-0000-4000-8000-000000000101"
	const guardianID = "00000000-0000-4000-8000-000000000002"
	_, err := a.db.ExecContext(ctx, `INSERT INTO students(id,student_no,full_name,class_name,program_name,academic_year,status) VALUES(?,?,?,?,?,?,?) ON DUPLICATE KEY UPDATE full_name=VALUES(full_name),class_name=VALUES(class_name),program_name=VALUES(program_name),academic_year=VALUES(academic_year)`, studentID, "ZB-DEMO-001", "Ahmad Fulan Demo", "Kelas A", "Tahfidz", "2026/2027", "ACTIVE")
	if err != nil {
		return err
	}
	_, err = a.db.ExecContext(ctx, `INSERT INTO guardian_relationships(id,guardian_user_id,student_id,relationship,status,approved_by,approved_at) VALUES(?,?,?,?,?,?,UTC_TIMESTAMP(6)) ON DUPLICATE KEY UPDATE status='APPROVED',relationship=VALUES(relationship)`, "00000000-0000-4000-8000-000000000201", guardianID, studentID, "FATHER", "APPROVED", "00000000-0000-4000-8000-000000000001")
	return err
}

func (a *app) listStudentsAdmin(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	q := strings.TrimSpace(r.URL.Query().Get("q"))
	like := "%" + q + "%"
	rows, err := a.db.QueryContext(r.Context(), `SELECT id,student_no,full_name,photo_url,class_name,program_name,academic_year,status,created_at FROM students WHERE (?='' OR student_no LIKE ? OR full_name LIKE ?) ORDER BY full_name LIMIT 500`, q, like, like)
	if err != nil {
		httpx.Fail(w, r, 500, "QUERY_FAILED", "Could not load students")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id, no, name, status string
		var photo, class, program, year sql.NullString
		var created time.Time
		if rows.Scan(&id, &no, &name, &photo, &class, &program, &year, &status, &created) == nil {
			out = append(out, map[string]any{"id": id, "student_no": no, "full_name": name, "photo_url": photo.String, "class_name": class.String, "program_name": program.String, "academic_year": year.String, "status": status, "created_at": created})
		}
	}
	httpx.JSON(w, 200, out)
}

func (a *app) listGuardianLinksAdmin(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	rows, err := a.db.QueryContext(r.Context(), `SELECT g.id,g.guardian_user_id,g.student_id,s.student_no,s.full_name,g.relationship,g.status,g.approved_by,g.approved_at,g.created_at FROM guardian_relationships g JOIN students s ON s.id=g.student_id ORDER BY g.created_at DESC LIMIT 500`)
	if err != nil {
		httpx.Fail(w, r, 500, "QUERY_FAILED", "Could not load guardian links")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id, gid, sid, no, name, rel, status string
		var approvedBy sql.NullString
		var approvedAt sql.NullTime
		var created time.Time
		if rows.Scan(&id, &gid, &sid, &no, &name, &rel, &status, &approvedBy, &approvedAt, &created) == nil {
			out = append(out, map[string]any{"id": id, "guardian_user_id": gid, "student_id": sid, "student_no": no, "student_name": name, "relationship": rel, "status": status, "approved_by": approvedBy.String, "approved_at": nullableTime(approvedAt), "created_at": created})
		}
	}
	httpx.JSON(w, 200, out)
}

func (a *app) createGuardianLinkAdmin(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	actor, _ := a.claims(r)
	var in adminLinkIn
	if !httpx.Decode(w, r, &in) {
		return
	}
	in.GuardianUserID = strings.TrimSpace(in.GuardianUserID)
	in.StudentID = strings.TrimSpace(in.StudentID)
	in.Relationship = strings.ToUpper(strings.TrimSpace(in.Relationship))
	allowed := map[string]bool{"FATHER": true, "MOTHER": true, "GUARDIAN": true, "OTHER": true, "APPROVED_GUARDIAN": true}
	if in.GuardianUserID == "" || in.StudentID == "" || !allowed[in.Relationship] {
		httpx.Fail(w, r, http.StatusBadRequest, "VALIDATION", "Invalid guardian link")
		return
	}
	tx, err := a.db.BeginTx(r.Context(), nil)
	if err != nil {
		httpx.Fail(w, r, 500, "TX_FAILED", "Could not create guardian relationship")
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
	var existingID, existingStatus, existingRelationship string
	err = tx.QueryRowContext(r.Context(), `SELECT id,status,relationship FROM guardian_relationships WHERE guardian_user_id=? AND student_id=? FOR UPDATE`, in.GuardianUserID, in.StudentID).Scan(&existingID, &existingStatus, &existingRelationship)
	if err == nil {
		switch existingStatus {
		case "APPROVED":
			httpx.Fail(w, r, 409, "LINK_ALREADY_APPROVED", "Guardian relationship is already approved")
			return
		case "PENDING":
			httpx.Fail(w, r, 409, "LINK_PENDING", "Guardian relationship is already pending approval")
			return
		case "REVOKED", "REJECTED":
			if _, err = tx.ExecContext(r.Context(), `UPDATE guardian_relationships SET relationship=?,status='PENDING',approved_by=NULL,approved_at=NULL WHERE id=?`, in.Relationship, existingID); err != nil {
				httpx.Fail(w, r, 500, "UPDATE_FAILED", "Could not re-request guardian relationship")
				return
			}
			before := map[string]any{"status": existingStatus, "relationship": existingRelationship, "guardian_user_id": in.GuardianUserID, "student_id": in.StudentID}
			after := map[string]any{"status": "PENDING", "relationship": in.Relationship, "guardian_user_id": in.GuardianUserID, "student_id": in.StudentID}
			if err = auditx.Add(r.Context(), tx, auditx.FromRequest(r, actor.Sub, "GUARDIAN_LINK_REQUESTED", "guardian_relationship", existingID, before, after)); err != nil {
				httpx.Fail(w, r, 500, "AUDIT_ENQUEUE_FAILED", "Could not audit guardian relationship")
				return
			}
			if err = tx.Commit(); err != nil {
				httpx.Fail(w, r, 500, "COMMIT_FAILED", "Could not re-request guardian relationship")
				return
			}
			httpx.JSON(w, 201, map[string]any{"id": existingID, "status": "PENDING", "re_requested": true})
			return
		default:
			httpx.Fail(w, r, 409, "INVALID_LINK_STATE", "Guardian relationship state does not allow a new request")
			return
		}
	}
	if err != sql.ErrNoRows {
		httpx.Fail(w, r, 500, "QUERY_FAILED", "Could not validate guardian relationship")
		return
	}
	id := httpx.NewID()
	if _, err = tx.ExecContext(r.Context(), `INSERT INTO guardian_relationships(id,guardian_user_id,student_id,relationship) VALUES(?,?,?,?)`, id, in.GuardianUserID, in.StudentID, in.Relationship); err != nil {
		httpx.Fail(w, r, 409, "CREATE_FAILED", "Could not create guardian relationship")
		return
	}
	after := map[string]any{"status": "PENDING", "relationship": in.Relationship, "guardian_user_id": in.GuardianUserID, "student_id": in.StudentID}
	if err = auditx.Add(r.Context(), tx, auditx.FromRequest(r, actor.Sub, "GUARDIAN_LINK_REQUESTED", "guardian_relationship", id, nil, after)); err != nil {
		httpx.Fail(w, r, 500, "AUDIT_ENQUEUE_FAILED", "Could not audit guardian relationship")
		return
	}
	if err = tx.Commit(); err != nil {
		httpx.Fail(w, r, 500, "COMMIT_FAILED", "Could not create guardian relationship")
		return
	}
	httpx.JSON(w, 201, map[string]any{"id": id, "status": "PENDING", "re_requested": false})
}

func (a *app) listAttendanceAdmin(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	studentID := strings.TrimSpace(r.URL.Query().Get("student_id"))
	rows, err := a.db.QueryContext(r.Context(), `SELECT a.id,a.student_id,s.student_no,s.full_name,a.attendance_date,a.status,a.note,a.recorded_by,a.created_at FROM attendance a JOIN students s ON s.id=a.student_id WHERE (?='' OR a.student_id=?) ORDER BY a.attendance_date DESC,a.created_at DESC LIMIT 500`, studentID, studentID)
	if err != nil {
		httpx.Fail(w, r, 500, "QUERY_FAILED", "Could not load attendance")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id, sid, no, name, status string
		var d time.Time
		var note, rec sql.NullString
		var created time.Time
		if rows.Scan(&id, &sid, &no, &name, &d, &status, &note, &rec, &created) == nil {
			out = append(out, map[string]any{"id": id, "student_id": sid, "student_no": no, "student_name": name, "date": d.Format("2006-01-02"), "status": status, "note": note.String, "recorded_by": rec.String, "created_at": created})
		}
	}
	httpx.JSON(w, 200, out)
}

func nullableTime(v sql.NullTime) any {
	if !v.Valid {
		return nil
	}
	return v.Time
}
