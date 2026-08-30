package main

import (
	"database/sql"
	"net/http"
	"strings"
	"time"

	"github.com/zabisa/platform/packages/go/platform/auditx"
	"github.com/zabisa/platform/packages/go/platform/httpx"
)

type updateTargetIn struct {
	TargetJuz  float64 `json:"target_juz"`
	TargetDate string  `json:"target_date"`
}

func (a *app) updateTarget(w http.ResponseWriter, r *http.Request, p map[string]string) {
	actor, _ := a.claims(r)
	var in updateTargetIn
	if !httpx.Decode(w, r, &in) {
		return
	}
	if in.TargetJuz <= 0 || in.TargetJuz > 30 {
		httpx.Fail(w, r, http.StatusBadRequest, "VALIDATION", "target_juz must be between 0 and 30")
		return
	}
	var date any
	if strings.TrimSpace(in.TargetDate) != "" {
		d, err := time.Parse("2006-01-02", in.TargetDate)
		if err != nil {
			httpx.Fail(w, r, http.StatusBadRequest, "VALIDATION", "target_date must be YYYY-MM-DD")
			return
		}
		date = d
	}
	tx, err := a.db.BeginTx(r.Context(), nil)
	if err != nil {
		httpx.Fail(w, r, 500, "TX_FAILED", "Could not update tahfidz target")
		return
	}
	defer tx.Rollback()
	var studentID string
	var beforeJuz float64
	var beforeDate sql.NullTime
	if err = tx.QueryRowContext(r.Context(), `SELECT student_id,target_juz,target_date FROM tahfidz_targets WHERE id=? FOR UPDATE`, p["id"]).Scan(&studentID, &beforeJuz, &beforeDate); err == sql.ErrNoRows {
		httpx.Fail(w, r, 404, "NOT_FOUND", "Tahfidz target not found")
		return
	} else if err != nil {
		httpx.Fail(w, r, 500, "QUERY_FAILED", "Could not load tahfidz target")
		return
	}
	if _, err = tx.ExecContext(r.Context(), `UPDATE tahfidz_targets SET target_juz=?,target_date=? WHERE id=?`, in.TargetJuz, date, p["id"]); err != nil {
		httpx.Fail(w, r, http.StatusInternalServerError, "UPDATE_FAILED", "Could not update tahfidz target")
		return
	}
	beforeDateValue := ""
	if beforeDate.Valid {
		beforeDateValue = beforeDate.Time.Format("2006-01-02")
	}
	before := map[string]any{"student_id": studentID, "target_juz": beforeJuz, "target_date": beforeDateValue}
	after := map[string]any{"student_id": studentID, "target_juz": in.TargetJuz, "target_date": strings.TrimSpace(in.TargetDate)}
	if err = auditx.Add(r.Context(), tx, auditx.FromRequest(r, actor.Sub, "TAHFIDZ_TARGET_UPDATED", "tahfidz_target", p["id"], before, after)); err != nil {
		httpx.Fail(w, r, 500, "AUDIT_ENQUEUE_FAILED", "Could not audit tahfidz target")
		return
	}
	if err = tx.Commit(); err != nil {
		httpx.Fail(w, r, 500, "COMMIT_FAILED", "Could not update tahfidz target")
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"id": p["id"], "target_juz": in.TargetJuz})
}
