package auditx

import (
	"context"
	"net/http"
	"testing"

	"github.com/zabisa/platform/packages/go/platform/httpx"
)

func TestFromRequestCarriesSafeCorrelationMetadata(t *testing.T) {
	r, err := http.NewRequestWithContext(context.Background(), http.MethodPatch, "http://example.test/resource", nil)
	if err != nil {
		t.Fatal(err)
	}
	r.Header.Set("X-Forwarded-For", "10.0.0.7, 10.0.0.8")
	r.Header.Set("User-Agent", "phase36-test")
	r.Header.Set("traceparent", "00-0123456789abcdef0123456789abcdef-0123456789abcdef-01")

	record := FromRequest(r, "actor-1", "UPDATED", "resource", httpx.NewID(), map[string]any{"status": "OLD"}, map[string]any{"status": "NEW"})
	if record.IP != "10.0.0.7" || record.UserAgent != "phase36-test" || record.TraceID != "0123456789abcdef0123456789abcdef" {
		t.Fatalf("unexpected record metadata: %+v", record)
	}
}
