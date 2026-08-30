package outbox

import "testing"

func TestWorkerRoutesAuditEventsToAuditEndpoint(t *testing.T) {
	w := Worker{Endpoint: "http://notification", AuditEndpoint: "http://identity/audit"}
	if got := w.endpointFor("Audit.Record"); got != "http://identity/audit" {
		t.Fatalf("audit endpoint = %q", got)
	}
	if got := w.endpointFor("GradePublished"); got != "http://notification" {
		t.Fatalf("notification endpoint = %q", got)
	}
}
