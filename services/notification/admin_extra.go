package main

import (
	"context"
	"database/sql"
	"net/http"
	"strings"
	"time"

	"github.com/zabisa/platform/packages/go/platform/auditx"
	"github.com/zabisa/platform/packages/go/platform/database"
	"github.com/zabisa/platform/packages/go/platform/httpx"
)

type adminNotificationIn struct {
	UserID      string `json:"user_id"`
	Type        string `json:"type"`
	Title       string `json:"title"`
	Message     string `json:"message"`
	DeepLink    string `json:"deep_link"`
	ScheduledAt string `json:"scheduled_at"`
}

func (a *app) createAdminNotification(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	actor, _ := a.access.Claims(r)
	var in adminNotificationIn
	if !httpx.Decode(w, r, &in) {
		return
	}
	in.Type = strings.ToUpper(strings.TrimSpace(in.Type))
	if in.Type == "" || strings.TrimSpace(in.Title) == "" || strings.TrimSpace(in.Message) == "" {
		httpx.Fail(w, r, 400, "VALIDATION", "type, title and message are required")
		return
	}
	if strings.TrimSpace(in.ScheduledAt) != "" {
		t, err := time.Parse(time.RFC3339, in.ScheduledAt)
		if err != nil {
			httpx.Fail(w, r, 400, "VALIDATION", "scheduled_at must be RFC3339")
			return
		}
		id := httpx.NewID()
		tx, err := a.db.BeginTx(r.Context(), nil)
		if err != nil {
			httpx.Fail(w, r, 500, "TX_FAILED", "Could not schedule notification")
			return
		}
		defer tx.Rollback()
		if _, err = tx.ExecContext(r.Context(), `INSERT INTO scheduled_notifications(id,user_id,type,title,message,deep_link,scheduled_at) VALUES(?,?,?,?,?,?,?)`, id, database.NullString(in.UserID), in.Type, in.Title, in.Message, database.NullString(in.DeepLink), t.UTC()); err != nil {
			httpx.Fail(w, r, 500, "SAVE_FAILED", "Could not schedule notification")
			return
		}
		after := map[string]any{"user_id": strings.TrimSpace(in.UserID), "type": in.Type, "title": strings.TrimSpace(in.Title), "scheduled_at": t.UTC()}
		if err = auditx.Add(r.Context(), tx, auditx.FromRequest(r, actor.Sub, "NOTIFICATION_SCHEDULED", "scheduled_notification", id, nil, after)); err != nil {
			httpx.Fail(w, r, 500, "AUDIT_ENQUEUE_FAILED", "Could not audit scheduled notification")
			return
		}
		if err = tx.Commit(); err != nil {
			httpx.Fail(w, r, 500, "COMMIT_FAILED", "Could not schedule notification")
			return
		}
		httpx.JSON(w, 201, map[string]any{"id": id, "status": "SCHEDULED"})
		return
	}
	id := httpx.NewID()
	tx, err := a.db.BeginTx(r.Context(), nil)
	if err != nil {
		httpx.Fail(w, r, 500, "TX_FAILED", "Could not create notification")
		return
	}
	defer tx.Rollback()
	if _, err = tx.ExecContext(r.Context(), `INSERT INTO notifications(id,user_id,type,title,message,deep_link) VALUES(?,?,?,?,?,?)`, id, database.NullString(in.UserID), in.Type, in.Title, in.Message, database.NullString(in.DeepLink)); err != nil {
		httpx.Fail(w, r, 500, "SAVE_FAILED", "Could not create notification")
		return
	}
	after := map[string]any{"user_id": strings.TrimSpace(in.UserID), "type": in.Type, "title": strings.TrimSpace(in.Title), "delivery": "QUEUED"}
	if err = auditx.Add(r.Context(), tx, auditx.FromRequest(r, actor.Sub, "NOTIFICATION_CREATED", "notification", id, nil, after)); err != nil {
		httpx.Fail(w, r, 500, "AUDIT_ENQUEUE_FAILED", "Could not audit notification")
		return
	}
	if err = tx.Commit(); err != nil {
		httpx.Fail(w, r, 500, "COMMIT_FAILED", "Could not create notification")
		return
	}
	httpx.JSON(w, 201, map[string]any{"id": id, "delivery": "QUEUED"})
}

func (a *app) listAdminNotifications(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	rows, err := a.db.QueryContext(r.Context(), `SELECT id,user_id,type,title,message,deep_link,read_at,created_at FROM notifications ORDER BY created_at DESC LIMIT 500`)
	if err != nil {
		httpx.Fail(w, r, 500, "QUERY_FAILED", "Could not load notifications")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id, typ, title, msg string
		var uid, deep sql.NullString
		var read sql.NullTime
		var created time.Time
		if rows.Scan(&id, &uid, &typ, &title, &msg, &deep, &read, &created) == nil {
			out = append(out, map[string]any{"id": id, "user_id": uid.String, "type": typ, "title": title, "message": msg, "deep_link": deep.String, "read": read.Valid, "created_at": created})
		}
	}
	httpx.JSON(w, 200, out)
}

func (a *app) listScheduledNotifications(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	rows, err := a.db.QueryContext(r.Context(), `SELECT id,user_id,type,title,message,deep_link,scheduled_at,processed_at,created_at FROM scheduled_notifications ORDER BY scheduled_at DESC LIMIT 300`)
	if err != nil {
		httpx.Fail(w, r, 500, "QUERY_FAILED", "Could not load schedules")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id, typ, title, msg string
		var uid, deep sql.NullString
		var scheduled, created time.Time
		var processed sql.NullTime
		if rows.Scan(&id, &uid, &typ, &title, &msg, &deep, &scheduled, &processed, &created) == nil {
			out = append(out, map[string]any{"id": id, "user_id": uid.String, "type": typ, "title": title, "message": msg, "deep_link": deep.String, "scheduled_at": scheduled, "processed_at": nullableNotificationTime(processed), "created_at": created})
		}
	}
	httpx.JSON(w, 200, out)
}

func (a *app) runScheduler(ctx context.Context) {
	ticker := time.NewTicker(15 * time.Second)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			a.dispatchDue(ctx)
		}
	}
}
func (a *app) dispatchDue(ctx context.Context) {
	rows, err := a.db.QueryContext(ctx, `SELECT id,user_id,type,title,message,deep_link FROM scheduled_notifications WHERE processed_at IS NULL AND scheduled_at<=UTC_TIMESTAMP(6) ORDER BY scheduled_at LIMIT 100`)
	if err != nil {
		return
	}
	defer rows.Close()
	type item struct {
		id, typ, title, msg string
		uid, deep           sql.NullString
	}
	items := []item{}
	for rows.Next() {
		var x item
		if rows.Scan(&x.id, &x.uid, &x.typ, &x.title, &x.msg, &x.deep) == nil {
			items = append(items, x)
		}
	}
	for _, x := range items {
		tx, err := a.db.BeginTx(ctx, nil)
		if err != nil {
			continue
		}
		if _, err = tx.ExecContext(ctx, `INSERT INTO notifications(id,user_id,type,title,message,deep_link) VALUES(?,?,?,?,?,?)`, httpx.NewID(), nullableString(x.uid), x.typ, x.title, x.msg, nullableString(x.deep)); err == nil {
			_, err = tx.ExecContext(ctx, `UPDATE scheduled_notifications SET processed_at=UTC_TIMESTAMP(6) WHERE id=? AND processed_at IS NULL`, x.id)
		}
		if err == nil {
			_ = tx.Commit()
		} else {
			_ = tx.Rollback()
		}
	}
}
func nullableString(v sql.NullString) any {
	if !v.Valid || strings.TrimSpace(v.String) == "" {
		return nil
	}
	return v.String
}
func nullableNotificationTime(v sql.NullTime) any {
	if !v.Valid {
		return nil
	}
	return v.Time
}
