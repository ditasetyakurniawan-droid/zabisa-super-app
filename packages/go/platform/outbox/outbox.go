package outbox

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"time"

	"github.com/zabisa/platform/packages/go/platform/httpx"
)

type Event struct {
	ID        string          `json:"id"`
	EventType string          `json:"event_type"`
	Payload   json.RawMessage `json:"payload"`
}

func Add(ctx context.Context, tx *sql.Tx, eventType string, payload any) error {
	b, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("marshal outbox payload: %w", err)
	}
	_, err = tx.ExecContext(ctx, `INSERT INTO outbox_events(id,event_type,payload) VALUES(?,?,?)`, httpx.NewID(), eventType, b)
	return err
}

type Worker struct {
	DB            *sql.DB
	Endpoint      string
	AuditEndpoint string
	InternalKey   string
	Client        *http.Client
	Service       string
}

func (w Worker) Run(ctx context.Context) {
	if w.Client == nil {
		w.Client = &http.Client{Timeout: 5 * time.Second}
	}
	ticker := time.NewTicker(2 * time.Second)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			w.deliverBatch(ctx)
		}
	}
}

func (w Worker) deliverBatch(ctx context.Context) {
	rows, err := w.DB.QueryContext(ctx, `SELECT id,event_type,payload FROM outbox_events WHERE processed_at IS NULL AND next_attempt_at<=UTC_TIMESTAMP(6) ORDER BY created_at LIMIT 25`)
	if err != nil {
		slog.Error("outbox query", "service", w.Service, "error", err)
		return
	}
	defer rows.Close()
	var events []Event
	for rows.Next() {
		var e Event
		if err := rows.Scan(&e.ID, &e.EventType, &e.Payload); err == nil {
			events = append(events, e)
		}
	}
	for _, e := range events {
		w.deliver(ctx, e)
	}
}

func (w Worker) endpointFor(eventType string) string {
	if eventType == "Audit.Record" {
		return w.AuditEndpoint
	}
	return w.Endpoint
}

func (w Worker) deliver(ctx context.Context, e Event) {
	target := w.endpointFor(e.EventType)
	if target == "" {
		_, _ = w.DB.ExecContext(ctx, `UPDATE outbox_events SET attempts=attempts+1,next_attempt_at=DATE_ADD(UTC_TIMESTAMP(6), INTERVAL LEAST(300, POW(2,LEAST(attempts,8))) SECOND) WHERE id=?`, e.ID)
		slog.Warn("outbox route missing", "service", w.Service, "event_id", e.ID, "event_type", e.EventType)
		return
	}
	body, _ := json.Marshal(e)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, target, bytes.NewReader(body))
	if err != nil {
		return
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Internal-Key", w.InternalKey)
	req.Header.Set("X-Source-Service", w.Service)
	res, err := w.Client.Do(req)
	if err == nil && res.Body != nil {
		defer res.Body.Close()
	}
	if err == nil && res.StatusCode >= 200 && res.StatusCode < 300 {
		_, _ = w.DB.ExecContext(ctx, `UPDATE outbox_events SET processed_at=UTC_TIMESTAMP(6) WHERE id=? AND processed_at IS NULL`, e.ID)
		return
	}
	_, _ = w.DB.ExecContext(ctx, `UPDATE outbox_events SET attempts=attempts+1,next_attempt_at=DATE_ADD(UTC_TIMESTAMP(6), INTERVAL LEAST(300, POW(2,LEAST(attempts,8))) SECOND) WHERE id=?`, e.ID)
	slog.Warn("outbox delivery failed", "service", w.Service, "event_id", e.ID, "event_type", e.EventType, "error", err)
}
