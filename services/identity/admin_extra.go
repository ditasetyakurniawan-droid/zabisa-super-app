package main

import (
	"database/sql"
	"encoding/json"
	"errors"
	"net/http"
	"net/mail"
	"strings"
	"time"

	mysql "github.com/go-sql-driver/mysql"
	"github.com/zabisa/platform/packages/go/platform/auditx"
	"github.com/zabisa/platform/packages/go/platform/auth"
	"github.com/zabisa/platform/packages/go/platform/authz"
	"github.com/zabisa/platform/packages/go/platform/httpx"
	"github.com/zabisa/platform/packages/go/platform/outbox"
	"github.com/zabisa/platform/packages/go/platform/router"
)

type createUserIn struct {
	Email       string `json:"email"`
	Phone       string `json:"phone"`
	Password    string `json:"password"`
	DisplayName string `json:"display_name"`
	Role        string `json:"role"`
}
type updateUserAccessIn struct {
	Role   string `json:"role"`
	Status string `json:"status"`
}

func (a *app) claims(r *http.Request) (auth.Claims, error) {
	raw := strings.TrimSpace(strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer "))
	return auth.Verify(a.cfg.JWTKey, raw)
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

func (a *app) requirePermission(permission authz.Permission, h router.HandlerFunc) router.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request, p map[string]string) {
		c, err := a.claims(r)
		if err != nil {
			httpx.Fail(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "Authentication required")
			return
		}
		if !authz.Has(c.Role, permission) {
			httpx.Fail(w, r, http.StatusForbidden, "FORBIDDEN", "Insufficient permission")
			return
		}
		h(w, r, p)
	}
}

func (a *app) sessionStatus(w http.ResponseWriter, r *http.Request, p map[string]string) {
	var userID, role, status string
	var expires time.Time
	var revoked sql.NullTime
	err := a.db.QueryRowContext(r.Context(), `SELECT s.user_id,u.role,u.status,s.expires_at,s.revoked_at FROM sessions s JOIN users u ON u.id=s.user_id WHERE s.id=?`, p["id"]).Scan(&userID, &role, &status, &expires, &revoked)
	if err == sql.ErrNoRows {
		httpx.Fail(w, r, http.StatusNotFound, "SESSION_NOT_FOUND", "Session not found")
		return
	}
	if err != nil {
		httpx.Fail(w, r, http.StatusInternalServerError, "QUERY_FAILED", "Could not validate session")
		return
	}
	active := !revoked.Valid && status == "ACTIVE" && time.Now().UTC().Before(expires)
	httpx.JSON(w, http.StatusOK, map[string]any{"active": active, "user_id": userID, "role": role, "status": status, "expires_at": expires})
}

func (a *app) me(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	c, err := a.claims(r)
	if err != nil {
		httpx.Fail(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "Authentication required")
		return
	}
	var email, name, role, status string
	var phone sql.NullString
	err = a.db.QueryRowContext(r.Context(), `SELECT email,phone,display_name,role,status FROM users WHERE id=?`, c.Sub).Scan(&email, &phone, &name, &role, &status)
	if err != nil {
		httpx.Fail(w, r, http.StatusNotFound, "NOT_FOUND", "User not found")
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"id": c.Sub, "email": email, "phone": phone.String, "name": name, "role": role, "status": status})
}

func (a *app) listUsers(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	q := strings.TrimSpace(r.URL.Query().Get("q"))
	like := "%" + q + "%"
	rows, err := a.db.QueryContext(r.Context(), `SELECT id,email,phone,display_name,role,status,created_at FROM users WHERE (?='' OR email LIKE ? OR display_name LIKE ?) ORDER BY created_at DESC LIMIT 300`, q, like, like)
	if err != nil {
		httpx.Fail(w, r, http.StatusInternalServerError, "QUERY_FAILED", "Could not load users")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id, email, name, role, status string
		var phone sql.NullString
		var created time.Time
		if rows.Scan(&id, &email, &phone, &name, &role, &status, &created) == nil {
			out = append(out, map[string]any{"id": id, "email": email, "phone": phone.String, "display_name": name, "role": role, "status": status, "created_at": created})
		}
	}
	httpx.JSON(w, http.StatusOK, out)
}

func (a *app) listGuardianCandidates(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	rows, err := a.db.QueryContext(r.Context(), `SELECT id,email,display_name,role,status FROM users WHERE role IN ('GUARDIAN','WALI_SANTRI') AND status='ACTIVE' ORDER BY display_name,email LIMIT 500`)
	if err != nil {
		httpx.Fail(w, r, http.StatusInternalServerError, "QUERY_FAILED", "Could not load guardian candidates")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id, email, name, role, status string
		if rows.Scan(&id, &email, &name, &role, &status) == nil {
			out = append(out, map[string]any{"id": id, "email": email, "display_name": name, "role": role, "status": status})
		}
	}
	httpx.JSON(w, http.StatusOK, out)
}

func (a *app) listNotificationCandidates(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	rows, err := a.db.QueryContext(r.Context(), `SELECT id,email,display_name,role,status FROM users WHERE status='ACTIVE' ORDER BY display_name,email LIMIT 1000`)
	if err != nil {
		httpx.Fail(w, r, http.StatusInternalServerError, "QUERY_FAILED", "Could not load notification candidates")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id, email, name, role, status string
		if rows.Scan(&id, &email, &name, &role, &status) == nil {
			out = append(out, map[string]any{"id": id, "email": email, "display_name": name, "role": role, "status": status})
		}
	}
	httpx.JSON(w, http.StatusOK, out)
}

func (a *app) createUser(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	actor, _ := a.claims(r)
	var in createUserIn
	if !httpx.Decode(w, r, &in) {
		return
	}
	in.Email = strings.ToLower(strings.TrimSpace(in.Email))
	in.DisplayName = strings.TrimSpace(in.DisplayName)
	in.Role = strings.ToUpper(strings.TrimSpace(in.Role))
	if in.Email == "" || in.DisplayName == "" || len(in.Password) < 12 {
		httpx.Fail(w, r, http.StatusBadRequest, "VALIDATION", "email, display_name and password (min 12 chars) are required")
		return
	}
	parsedEmail, err := mail.ParseAddress(in.Email)
	if err != nil || strings.ToLower(strings.TrimSpace(parsedEmail.Address)) != in.Email {
		httpx.Fail(w, r, http.StatusBadRequest, "INVALID_EMAIL", "Email tidak valid")
		return
	}
	allowed := map[string]bool{
		"REGISTERED_PUBLIC": true, "DONOR": true, "GUARDIAN": true, "WALI_SANTRI": true,
		"USTADZ": true, "GURU_AGAMA": true, "GURU_AKADEMIK": true, "WALI_KELAS": true,
		"OPERATOR": true, "FINANCE": true, "CONTENT_EDITOR": true, "ADMIN": true, "SUPER_ADMIN": true,
	}
	if !allowed[in.Role] {
		httpx.Fail(w, r, http.StatusBadRequest, "VALIDATION", "Invalid role")
		return
	}
	if !authz.IsSuperAdmin(actor.Role) && (in.Role == "ADMIN" || in.Role == "SUPER_ADMIN") {
		httpx.Fail(w, r, http.StatusForbidden, "FORBIDDEN", "Only SUPER_ADMIN can create privileged administrators")
		return
	}
	hash, err := auth.HashPassword(in.Password)
	if err != nil {
		httpx.Fail(w, r, http.StatusInternalServerError, "PASSWORD_FAILED", "Could not secure password")
		return
	}
	id := httpx.NewID()
	tx, err := a.db.BeginTx(r.Context(), nil)
	if err != nil {
		httpx.Fail(w, r, http.StatusInternalServerError, "TX_FAILED", "Could not create user")
		return
	}
	defer tx.Rollback()
	_, err = tx.ExecContext(r.Context(), `INSERT INTO users(id,email,phone,password_hash,display_name,role) VALUES(?,?,?,?,?,?)`, id, in.Email, nullIfEmpty(in.Phone), hash, in.DisplayName, in.Role)
	if err != nil {
		var mysqlErr *mysql.MySQLError
		if errors.As(err, &mysqlErr) && mysqlErr.Number == 1062 {
			httpx.Fail(w, r, http.StatusConflict, "EMAIL_EXISTS", "Email sudah terdaftar")
			return
		}
		httpx.Fail(w, r, http.StatusInternalServerError, "CREATE_FAILED", "Could not create user")
		return
	}
	if err = a.writeAuditTx(r, tx, actor.Sub, "USER_CREATED", "user", id, nil, map[string]any{"email": in.Email, "display_name": in.DisplayName, "role": in.Role, "status": "ACTIVE"}); err != nil {
		httpx.Fail(w, r, http.StatusInternalServerError, "AUDIT_WRITE_FAILED", "Could not create user audit")
		return
	}
	if err = tx.Commit(); err != nil {
		httpx.Fail(w, r, http.StatusInternalServerError, "COMMIT_FAILED", "Could not create user")
		return
	}
	httpx.JSON(w, http.StatusCreated, map[string]string{"id": id})
}

func (a *app) updateUserAccess(w http.ResponseWriter, r *http.Request, p map[string]string) {
	actor, _ := a.claims(r)
	if !authz.IsSuperAdmin(actor.Role) {
		httpx.Fail(w, r, http.StatusForbidden, "FORBIDDEN", "Only SUPER_ADMIN can change roles or account status")
		return
	}
	var in updateUserAccessIn
	if !httpx.Decode(w, r, &in) {
		return
	}
	in.Role = authz.NormalizeRole(in.Role)
	in.Status = strings.ToUpper(strings.TrimSpace(in.Status))
	allowedRoles := map[string]bool{
		"REGISTERED_PUBLIC": true, "DONOR": true, "GUARDIAN": true, "WALI_SANTRI": true,
		"USTADZ": true, "GURU_AGAMA": true, "GURU_AKADEMIK": true, "WALI_KELAS": true,
		"OPERATOR": true, "FINANCE": true, "CONTENT_EDITOR": true, "ADMIN": true, "SUPER_ADMIN": true,
	}
	if !allowedRoles[in.Role] || !map[string]bool{"ACTIVE": true, "INACTIVE": true}[in.Status] {
		httpx.Fail(w, r, http.StatusBadRequest, "VALIDATION", "role or status is invalid")
		return
	}
	if actor.Sub == p["id"] && (in.Role != "SUPER_ADMIN" || in.Status != "ACTIVE") {
		httpx.Fail(w, r, http.StatusConflict, "SELF_LOCKOUT", "You cannot remove your own active SUPER_ADMIN access")
		return
	}
	var beforeRole, beforeStatus string
	if err := a.db.QueryRowContext(r.Context(), `SELECT role,status FROM users WHERE id=?`, p["id"]).Scan(&beforeRole, &beforeStatus); err == sql.ErrNoRows {
		httpx.Fail(w, r, http.StatusNotFound, "NOT_FOUND", "User not found")
		return
	} else if err != nil {
		httpx.Fail(w, r, http.StatusInternalServerError, "QUERY_FAILED", "Could not load user")
		return
	}
	if beforeRole == "SUPER_ADMIN" && (in.Role != "SUPER_ADMIN" || in.Status != "ACTIVE") {
		var activeSuperAdmins int
		if err := a.db.QueryRowContext(r.Context(), `SELECT COUNT(*) FROM users WHERE role='SUPER_ADMIN' AND status='ACTIVE'`).Scan(&activeSuperAdmins); err != nil {
			httpx.Fail(w, r, http.StatusInternalServerError, "QUERY_FAILED", "Could not validate administrator quorum")
			return
		}
		if activeSuperAdmins <= 1 {
			httpx.Fail(w, r, http.StatusConflict, "LAST_SUPER_ADMIN", "The last active SUPER_ADMIN cannot be demoted or deactivated")
			return
		}
	}
	tx, err := a.db.BeginTx(r.Context(), nil)
	if err != nil {
		httpx.Fail(w, r, http.StatusInternalServerError, "TX_FAILED", "Could not update access")
		return
	}
	defer tx.Rollback()
	if _, err = tx.ExecContext(r.Context(), `UPDATE users SET role=?,status=? WHERE id=?`, in.Role, in.Status, p["id"]); err != nil {
		httpx.Fail(w, r, http.StatusInternalServerError, "UPDATE_FAILED", "Could not update access")
		return
	}
	// Security invariant: any role/status change revokes all existing target sessions.
	if _, err = tx.ExecContext(r.Context(), `UPDATE sessions SET revoked_at=COALESCE(revoked_at,UTC_TIMESTAMP(6)) WHERE user_id=?`, p["id"]); err != nil {
		httpx.Fail(w, r, http.StatusInternalServerError, "SESSION_REVOKE_FAILED", "Could not revoke existing sessions")
		return
	}
	if err = a.writeAuditTx(r, tx, actor.Sub, "USER_ACCESS_CHANGED", "user", p["id"], map[string]any{"role": beforeRole, "status": beforeStatus}, map[string]any{"role": in.Role, "status": in.Status}); err != nil {
		httpx.Fail(w, r, http.StatusInternalServerError, "AUDIT_WRITE_FAILED", "Could not audit access change")
		return
	}
	if err = tx.Commit(); err != nil {
		httpx.Fail(w, r, http.StatusInternalServerError, "COMMIT_FAILED", "Could not update access")
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"id": p["id"], "role": in.Role, "status": in.Status, "sessions_revoked": true})
}

func (a *app) ingestAuditEvent(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	var event outbox.Event
	if !httpx.Decode(w, r, &event) {
		return
	}
	if event.ID == "" || event.EventType != auditx.EventType {
		httpx.Fail(w, r, http.StatusBadRequest, "INVALID_AUDIT_EVENT", "Invalid audit event")
		return
	}
	var record auditx.Record
	if err := json.Unmarshal(event.Payload, &record); err != nil || strings.TrimSpace(record.Action) == "" || strings.TrimSpace(record.Resource) == "" {
		httpx.Fail(w, r, http.StatusBadRequest, "INVALID_AUDIT_PAYLOAD", "Invalid audit payload")
		return
	}
	var beforeJSON, afterJSON any
	if record.Before != nil {
		if b, err := json.Marshal(record.Before); err == nil {
			beforeJSON = string(b)
		}
	}
	if record.After != nil {
		if b, err := json.Marshal(record.After); err == nil {
			afterJSON = string(b)
		}
	}
	sourceService := strings.TrimSpace(r.Header.Get("X-Source-Service"))
	if sourceService == "" {
		httpx.Fail(w, r, http.StatusBadRequest, "SOURCE_REQUIRED", "Audit source service is required")
		return
	}
	_, err := a.db.ExecContext(r.Context(), `INSERT INTO audit_logs(id,actor_id,action,resource,resource_id,source_service,before_json,after_json,ip,user_agent,request_id,trace_id) VALUES(?,?,?,?,?,?,?,?,?,?,?,?) ON DUPLICATE KEY UPDATE id=id`, event.ID, nullIfEmpty(record.ActorID), record.Action, record.Resource, nullIfEmpty(record.ResourceID), sourceService, beforeJSON, afterJSON, nullIfEmpty(record.IP), nullIfEmpty(record.UserAgent), nullIfEmpty(record.RequestID), nullIfEmpty(record.TraceID))
	if err != nil {
		httpx.Fail(w, r, http.StatusInternalServerError, "AUDIT_WRITE_FAILED", "Could not persist audit event")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (a *app) listAuditLogs(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	rows, err := a.db.QueryContext(r.Context(), `SELECT id,actor_id,action,resource,resource_id,source_service,before_json,after_json,ip,user_agent,request_id,trace_id,created_at FROM audit_logs ORDER BY created_at DESC LIMIT 500`)
	if err != nil {
		httpx.Fail(w, r, http.StatusInternalServerError, "QUERY_FAILED", "Could not load audit logs")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id, action, resource string
		var actor, resourceID, sourceService, beforeJSON, afterJSON, ip, ua, requestID, traceID sql.NullString
		var created time.Time
		if rows.Scan(&id, &actor, &action, &resource, &resourceID, &sourceService, &beforeJSON, &afterJSON, &ip, &ua, &requestID, &traceID, &created) == nil {
			out = append(out, map[string]any{"id": id, "actor_id": actor.String, "action": action, "resource": resource, "resource_id": resourceID.String, "source_service": sourceService.String, "before": beforeJSON.String, "after": afterJSON.String, "ip": ip.String, "user_agent": ua.String, "request_id": requestID.String, "trace_id": traceID.String, "created_at": created})
		}
	}
	httpx.JSON(w, http.StatusOK, out)
}

func (a *app) writeAuditTx(r *http.Request, tx *sql.Tx, actor, action, resource, resourceID string, before, after any) error {
	var beforeJSON, afterJSON any
	if before != nil {
		if b, err := json.Marshal(before); err == nil {
			beforeJSON = string(b)
		} else {
			return err
		}
	}
	if after != nil {
		if b, err := json.Marshal(after); err == nil {
			afterJSON = string(b)
		} else {
			return err
		}
	}
	_, err := tx.ExecContext(r.Context(), `INSERT INTO audit_logs(id,actor_id,action,resource,resource_id,source_service,before_json,after_json,ip,user_agent,request_id,trace_id) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)`, httpx.NewID(), nullIfEmpty(actor), action, resource, nullIfEmpty(resourceID), "identity-service", beforeJSON, afterJSON, nullIfEmpty(clientIP(r)), nullIfEmpty(r.UserAgent()), nullIfEmpty(httpx.RequestID(r.Context())), nullIfEmpty(traceIDFromRequest(r)))
	return err
}

func (a *app) writeAudit(r *http.Request, actor, action, resource, resourceID string, before, after any) {
	// Identity audit records are append-only; there is intentionally no update/delete endpoint.
	var beforeJSON, afterJSON any
	if before != nil {
		if b, err := json.Marshal(before); err == nil {
			beforeJSON = string(b)
		}
	}
	if after != nil {
		if b, err := json.Marshal(after); err == nil {
			afterJSON = string(b)
		}
	}
	_, _ = a.db.ExecContext(r.Context(), `INSERT INTO audit_logs(id,actor_id,action,resource,resource_id,before_json,after_json,ip,user_agent,request_id,trace_id) VALUES(?,?,?,?,?,?,?,?,?,?,?)`, httpx.NewID(), nullIfEmpty(actor), action, resource, nullIfEmpty(resourceID), beforeJSON, afterJSON, nullIfEmpty(clientIP(r)), nullIfEmpty(r.UserAgent()), nullIfEmpty(r.Header.Get("X-Request-ID")), nullIfEmpty(traceIDFromRequest(r)))
}

func clientIP(r *http.Request) string {
	if v := strings.TrimSpace(strings.Split(r.Header.Get("X-Forwarded-For"), ",")[0]); v != "" {
		return v
	}
	return strings.TrimSpace(strings.Split(r.RemoteAddr, ":")[0])
}

func traceIDFromRequest(r *http.Request) string {
	parts := strings.Split(strings.TrimSpace(r.Header.Get("traceparent")), "-")
	if len(parts) >= 4 && len(parts[1]) == 32 {
		return parts[1]
	}
	return httpx.RequestID(r.Context())
}
