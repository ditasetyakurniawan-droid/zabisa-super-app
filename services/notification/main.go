package main

import (
	"context"
	"database/sql"
	"embed"
	"encoding/json"
	"fmt"
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
	"io"
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
type createIn struct {
	UserID   string `json:"user_id"`
	Type     string `json:"type"`
	Title    string `json:"title"`
	Message  string `json:"message"`
	DeepLink string `json:"deep_link"`
}
type eventIn struct {
	ID        string          `json:"id"`
	EventType string          `json:"event_type"`
	Payload   json.RawMessage `json:"payload"`
}

type deviceIn struct {
	Platform string `json:"platform"`
	Token    string `json:"token"`
}

func main() {
	cfg := config.Load("notification-service", "notification_db", 8087)
	db, err := database.Open(context.Background(), cfg.DSN())
	if err != nil {
		panic(err)
	}
	defer db.Close()
	if err = migrate.Apply(context.Background(), db, migrationFS, "migrations"); err != nil {
		panic(err)
	}
	a := &app{db, cfg}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go a.runScheduler(ctx)
	go outbox.Worker{DB: db, AuditEndpoint: envURL("AUDIT_SERVICE_URL", "http://identity:8081/internal/v1/audit-events"), InternalKey: cfg.InternalServiceKey, Service: cfg.Service}.Run(ctx)
	rt := router.New()
	rt.Handle("GET", "/health/live", health.Live)
	rt.Handle("GET", "/health/ready", health.Ready(db))
	rt.Handle("POST", "/internal/v1/notifications", a.internal(a.create))
	rt.Handle("POST", "/internal/v1/events", a.internal(a.handleEvent))
	rt.Handle("GET", "/api/v1/notifications", a.authed(a.list))
	rt.Handle("PATCH", "/api/v1/notifications/{id}/read", a.authed(a.read))
	rt.Handle("PATCH", "/api/v1/notifications/read-all", a.authed(a.readAll))
	rt.Handle("POST", "/api/v1/devices", a.authed(a.registerDevice))
	rt.Handle("POST", "/api/v1/admin/notifications", a.requirePermission(authz.NotificationsWrite, a.createAdminNotification))
	rt.Handle("GET", "/api/v1/admin/notifications", a.requirePermission(authz.NotificationsRead, a.listAdminNotifications))
	rt.Handle("GET", "/api/v1/admin/notifications/scheduled", a.requirePermission(authz.NotificationsRead, a.listScheduledNotifications))
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
func (a *app) internal(h router.HandlerFunc) router.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request, p map[string]string) {
		if a.cfg.InternalServiceKey == "" || r.Header.Get("X-Internal-Key") != a.cfg.InternalServiceKey {
			httpx.Fail(w, r, 403, "FORBIDDEN", "Invalid service credential")
			return
		}
		h(w, r, p)
	}
}
func (a *app) create(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	var in createIn
	if !httpx.Decode(w, r, &in) {
		return
	}
	if in.Type == "" || in.Title == "" || in.Message == "" {
		httpx.Fail(w, r, 400, "VALIDATION", "type, title and message are required")
		return
	}
	id := httpx.NewID()
	_, err := a.db.ExecContext(r.Context(), `INSERT INTO notifications(id,user_id,type,title,message,deep_link) VALUES(?,?,?,?,?,?)`, id, n(in.UserID), in.Type, in.Title, in.Message, n(in.DeepLink))
	if err != nil {
		httpx.Fail(w, r, 500, "SAVE_FAILED", "Could not create notification")
		return
	}
	slog.Info("push dispatch requested", "notification_id", id, "type", in.Type, "user_id_present", in.UserID != "")
	httpx.JSON(w, 201, map[string]any{"id": id, "delivery": "QUEUED"})
}
func (a *app) list(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	c, _ := a.claims(r)
	rows, err := a.db.QueryContext(r.Context(), `SELECT id,type,title,message,deep_link,read_at,created_at FROM notifications WHERE user_id=? OR user_id IS NULL ORDER BY created_at DESC LIMIT 200`, c.Sub)
	if err != nil {
		httpx.Fail(w, r, 500, "QUERY_FAILED", "Could not load notifications")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id, typ, title, msg string
		var deep sql.NullString
		var read sql.NullTime
		var created time.Time
		if rows.Scan(&id, &typ, &title, &msg, &deep, &read, &created) == nil {
			out = append(out, map[string]any{"id": id, "type": typ, "title": title, "message": msg, "deep_link": deep.String, "read": read.Valid, "created_at": created})
		}
	}
	httpx.JSON(w, 200, out)
}
func (a *app) read(w http.ResponseWriter, r *http.Request, p map[string]string) {
	c, _ := a.claims(r)
	res, err := a.db.ExecContext(r.Context(), `UPDATE notifications SET read_at=COALESCE(read_at,UTC_TIMESTAMP(6)) WHERE id=? AND (user_id=? OR user_id IS NULL)`, p["id"], c.Sub)
	if err != nil {
		httpx.Fail(w, r, 500, "UPDATE_FAILED", "Could not mark notification read")
		return
	}
	n, _ := res.RowsAffected()
	if n == 0 {
		httpx.Fail(w, r, 404, "NOT_FOUND", "Notification not found")
		return
	}
	w.WriteHeader(204)
}
func (a *app) readAll(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	c, _ := a.claims(r)
	_, err := a.db.ExecContext(r.Context(), `UPDATE notifications SET read_at=COALESCE(read_at,UTC_TIMESTAMP(6)) WHERE (user_id=? OR user_id IS NULL) AND read_at IS NULL`, c.Sub)
	if err != nil {
		httpx.Fail(w, r, 500, "UPDATE_FAILED", "Could not mark notifications read")
		return
	}
	w.WriteHeader(204)
}
func (a *app) registerDevice(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	c, _ := a.claims(r)
	var in deviceIn
	if !httpx.Decode(w, r, &in) {
		return
	}
	if !map[string]bool{"android": true, "ios": true}[strings.ToLower(in.Platform)] || strings.TrimSpace(in.Token) == "" {
		httpx.Fail(w, r, 400, "VALIDATION", "platform and token are invalid")
		return
	}
	_, err := a.db.ExecContext(r.Context(), `INSERT INTO device_tokens(id,user_id,platform,token) VALUES(?,?,?,?) ON DUPLICATE KEY UPDATE user_id=VALUES(user_id),platform=VALUES(platform),active=TRUE`, httpx.NewID(), c.Sub, strings.ToLower(in.Platform), in.Token)
	if err != nil {
		httpx.Fail(w, r, 500, "SAVE_FAILED", "Could not register device")
		return
	}
	w.WriteHeader(204)
}
func n(v string) any {
	if strings.TrimSpace(v) == "" {
		return nil
	}
	return strings.TrimSpace(v)
}

func (a *app) handleEvent(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	var in eventIn
	if !httpx.Decode(w, r, &in) {
		return
	}
	if in.ID == "" || in.EventType == "" {
		httpx.Fail(w, r, 400, "VALIDATION", "Invalid event")
		return
	}
	switch in.EventType {
	case "KajianPublished":
		var p struct{ KajianID, Title, DeepLink string }
		_ = json.Unmarshal(in.Payload, &p)
		if p.Title == "" {
			p.Title = "Kajian baru"
		}
		if err := a.insertNotification(r.Context(), "", "KAJIAN", p.Title, "Kajian baru telah dipublikasikan.", p.DeepLink); err != nil {
			httpx.Fail(w, r, 500, "EVENT_FAILED", "Could not persist notification")
			return
		}
	case "TahfidzEntryCreated":
		var p struct {
			StudentID string `json:"student_id"`
			EntryID   string `json:"entry_id"`
			Surah     string `json:"surah"`
			DeepLink  string `json:"deep_link"`
		}
		if json.Unmarshal(in.Payload, &p) != nil || p.StudentID == "" {
			httpx.Fail(w, r, 400, "VALIDATION", "Invalid tahfidz event")
			return
		}
		ids, err := a.guardians(r.Context(), p.StudentID)
		if err != nil {
			httpx.Fail(w, r, 502, "DEPENDENCY_FAILED", "Could not resolve guardians")
			return
		}
		for _, id := range ids {
			if err = a.insertNotification(r.Context(), id, "TAHFIDZ", "Setoran tahfidz baru", "Setoran tahfidz terbaru telah dicatat.", p.DeepLink); err != nil {
				httpx.Fail(w, r, 500, "EVENT_FAILED", "Could not persist notification")
				return
			}
		}
	case "GradePublished":
		var p struct {
			StudentID string `json:"student_id"`
			DeepLink  string `json:"deep_link"`
		}
		if json.Unmarshal(in.Payload, &p) != nil || p.StudentID == "" {
			httpx.Fail(w, r, 400, "VALIDATION", "Invalid grade event")
			return
		}
		ids, err := a.guardians(r.Context(), p.StudentID)
		if err != nil {
			httpx.Fail(w, r, 502, "DEPENDENCY_FAILED", "Could not resolve guardians")
			return
		}
		for _, id := range ids {
			if err = a.insertNotification(r.Context(), id, "ACADEMIC", "Nilai baru tersedia", "Nilai terbaru telah dipublikasikan.", p.DeepLink); err != nil {
				httpx.Fail(w, r, 500, "EVENT_FAILED", "Could not persist notification")
				return
			}
		}
	case "ReportPublished":
		var p struct {
			StudentID string `json:"student_id"`
			DeepLink  string `json:"deep_link"`
		}
		if json.Unmarshal(in.Payload, &p) != nil || p.StudentID == "" {
			httpx.Fail(w, r, 400, "VALIDATION", "Invalid report event")
			return
		}
		ids, err := a.guardians(r.Context(), p.StudentID)
		if err != nil {
			httpx.Fail(w, r, 502, "DEPENDENCY_FAILED", "Could not resolve guardians")
			return
		}
		for _, id := range ids {
			if err = a.insertNotification(r.Context(), id, "ACADEMIC", "Report baru tersedia", "Report perkembangan terbaru telah dipublikasikan.", p.DeepLink); err != nil {
				httpx.Fail(w, r, 500, "EVENT_FAILED", "Could not persist notification")
				return
			}
		}
	default:
		httpx.Fail(w, r, 422, "UNSUPPORTED_EVENT", "Event type is not supported")
		return
	}
	httpx.JSON(w, 202, map[string]string{"status": "ACCEPTED"})
}

func (a *app) guardians(ctx context.Context, studentID string) ([]string, error) {
	base := strings.TrimRight(envURL("STUDENT_SERVICE_URL", "http://student:8083"), "/")
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, base+"/internal/v1/students/"+studentID+"/guardians", nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("X-Internal-Key", a.cfg.InternalServiceKey)
	res, err := (&http.Client{Timeout: 5 * time.Second}).Do(req)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()
	b, err := io.ReadAll(io.LimitReader(res.Body, 1<<20))
	if err != nil {
		return nil, err
	}
	if res.StatusCode != 200 {
		return nil, fmt.Errorf("student service status %d", res.StatusCode)
	}
	var body struct {
		Data struct {
			GuardianUserIDs []string `json:"guardian_user_ids"`
		} `json:"data"`
	}
	if err = json.Unmarshal(b, &body); err != nil {
		return nil, err
	}
	return body.Data.GuardianUserIDs, nil
}

func (a *app) insertNotification(ctx context.Context, userID, typ, title, message, deep string) error {
	_, err := a.db.ExecContext(ctx, `INSERT INTO notifications(id,user_id,type,title,message,deep_link) VALUES(?,?,?,?,?,?)`, httpx.NewID(), n(userID), typ, title, message, n(deep))
	return err
}

func envURL(key, fallback string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return fallback
}
