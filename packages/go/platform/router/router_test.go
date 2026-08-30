package router

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestPathParameter(t *testing.T) {
	r := New()
	r.Handle(http.MethodGet, "/items/{id}", func(w http.ResponseWriter, _ *http.Request, p map[string]string) { _, _ = w.Write([]byte(p["id"])) })
	rr := httptest.NewRecorder()
	r.ServeHTTP(rr, httptest.NewRequest(http.MethodGet, "/items/abc", nil))
	if rr.Code != http.StatusOK || rr.Body.String() != "abc" {
		t.Fatalf("unexpected response: %d %s", rr.Code, rr.Body.String())
	}
}
