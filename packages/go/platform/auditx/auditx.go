package auditx

import (
	"context"
	"database/sql"
	"net/http"
	"strings"

	"github.com/zabisa/platform/packages/go/platform/httpx"
	"github.com/zabisa/platform/packages/go/platform/outbox"
)

const EventType = "Audit.Record"

type Record struct {
	ActorID    string `json:"actor_id"`
	Action     string `json:"action"`
	Resource   string `json:"resource"`
	ResourceID string `json:"resource_id"`
	Before     any    `json:"before,omitempty"`
	After      any    `json:"after,omitempty"`
	IP         string `json:"ip,omitempty"`
	UserAgent  string `json:"user_agent,omitempty"`
	RequestID  string `json:"request_id,omitempty"`
	TraceID    string `json:"trace_id,omitempty"`
}

func FromRequest(r *http.Request, actorID, action, resource, resourceID string, before, after any) Record {
	return Record{
		ActorID:    actorID,
		Action:     action,
		Resource:   resource,
		ResourceID: resourceID,
		Before:     before,
		After:      after,
		IP:         clientIP(r),
		UserAgent:  r.UserAgent(),
		RequestID:  httpx.RequestID(r.Context()),
		TraceID:    traceID(r),
	}
}

func Add(ctx context.Context, tx *sql.Tx, record Record) error {
	return outbox.Add(ctx, tx, EventType, record)
}

func clientIP(r *http.Request) string {
	if forwarded := strings.TrimSpace(strings.Split(r.Header.Get("X-Forwarded-For"), ",")[0]); forwarded != "" {
		return forwarded
	}
	host := strings.TrimSpace(r.RemoteAddr)
	if i := strings.LastIndex(host, ":"); i > -1 {
		host = host[:i]
	}
	return strings.Trim(host, "[]")
}

func traceID(r *http.Request) string {
	parts := strings.Split(strings.TrimSpace(r.Header.Get("traceparent")), "-")
	if len(parts) >= 4 && len(parts[1]) == 32 {
		return parts[1]
	}
	return httpx.RequestID(r.Context())
}
