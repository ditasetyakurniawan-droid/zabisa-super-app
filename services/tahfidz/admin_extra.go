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

type targetIn struct {
	StudentID  string  `json:"student_id"`
	TargetJuz  float64 `json:"target_juz"`
	TargetDate string  `json:"target_date"`
}

func (a *app) listEntriesAdmin(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	studentID := strings.TrimSpace(r.URL.Query().Get("student_id"))
	rows, err := a.db.QueryContext(r.Context(), `SELECT id,student_id,activity_date,surah,ayah_start,ayah_end,juz,page_no,activity_type,score,fluency,tajwid,makhraj,teacher_note,teacher_user_id,verification_status,created_at FROM tahfidz_entries WHERE (?='' OR student_id=?) ORDER BY activity_date DESC,created_at DESC LIMIT 500`, studentID, studentID)
	if err != nil {
		httpx.Fail(w, r, 500, "QUERY_FAILED", "Could not load tahfidz entries")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id, sid, surah, typ, teacher, status string
		var d, created time.Time
		var a1, a2 int
		var juz, page sql.NullInt64
		var score sql.NullFloat64
		var flu, taj, mak, note sql.NullString
		if rows.Scan(&id, &sid, &d, &surah, &a1, &a2, &juz, &page, &typ, &score, &flu, &taj, &mak, &note, &teacher, &status, &created) == nil {
			out = append(out, map[string]any{"id": id, "student_id": sid, "date": d.Format("2006-01-02"), "surah": surah, "ayah_start": a1, "ayah_end": a2, "juz": database.NullableInt(juz), "page": database.NullableInt(page), "activity_type": typ, "score": database.NullableFloat(score), "fluency": flu.String, "tajwid": taj.String, "makhraj": mak.String, "teacher_note": note.String, "teacher_user_id": teacher, "verification_status": status, "created_at": created})
		}
	}
	httpx.JSON(w, 200, out)
}

func (a *app) createTarget(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	actor, _ := a.access.Claims(r)
	var in targetIn
	if !httpx.Decode(w, r, &in) {
		return
	}
	in.StudentID = strings.TrimSpace(in.StudentID)
	if in.StudentID == "" || in.TargetJuz <= 0 || in.TargetJuz > 30 {
		httpx.Fail(w, r, 400, "VALIDATION", "student_id and target_juz between 0 and 30 are required")
		return
	}
	var targetDate any
	if strings.TrimSpace(in.TargetDate) != "" {
		d, err := time.Parse("2006-01-02", in.TargetDate)
		if err != nil {
			httpx.Fail(w, r, 400, "VALIDATION", "target_date must be YYYY-MM-DD")
			return
		}
		targetDate = d
	}
	id := httpx.NewID()
	tx, err := a.db.BeginTx(r.Context(), nil)
	if err != nil {
		httpx.Fail(w, r, 500, "TX_FAILED", "Could not save tahfidz target")
		return
	}
	defer tx.Rollback()
	if _, err = tx.ExecContext(r.Context(), `INSERT INTO tahfidz_targets(id,student_id,target_juz,target_date) VALUES(?,?,?,?)`, id, in.StudentID, in.TargetJuz, targetDate); err != nil {
		httpx.Fail(w, r, 500, "SAVE_FAILED", "Could not save tahfidz target")
		return
	}
	after := map[string]any{"student_id": in.StudentID, "target_juz": in.TargetJuz, "target_date": strings.TrimSpace(in.TargetDate)}
	if err = auditx.Add(r.Context(), tx, auditx.FromRequest(r, actor.Sub, "TAHFIDZ_TARGET_CREATED", "tahfidz_target", id, nil, after)); err != nil {
		httpx.Fail(w, r, 500, "AUDIT_ENQUEUE_FAILED", "Could not audit tahfidz target")
		return
	}
	if err = tx.Commit(); err != nil {
		httpx.Fail(w, r, 500, "COMMIT_FAILED", "Could not save tahfidz target")
		return
	}
	httpx.JSON(w, 201, map[string]string{"id": id})
}

func (a *app) listTargets(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	sid := strings.TrimSpace(r.URL.Query().Get("student_id"))
	rows, err := a.db.QueryContext(r.Context(), `SELECT id,student_id,target_juz,target_date,created_at FROM tahfidz_targets WHERE (?='' OR student_id=?) ORDER BY created_at DESC LIMIT 300`, sid, sid)
	if err != nil {
		httpx.Fail(w, r, 500, "QUERY_FAILED", "Could not load tahfidz targets")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id, student string
		var target float64
		var d sql.NullTime
		var created time.Time
		if rows.Scan(&id, &student, &target, &d, &created) == nil {
			out = append(out, map[string]any{"id": id, "student_id": student, "target_juz": target, "target_date": nullableTime2(d), "created_at": created})
		}
	}
	httpx.JSON(w, 200, out)
}
func nullableTime2(v sql.NullTime) any {
	if !v.Valid {
		return nil
	}
	return v.Time.Format("2006-01-02")
}
