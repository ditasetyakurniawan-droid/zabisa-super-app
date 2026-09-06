package access

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/zabisa/platform/packages/go/platform/auth"
	"github.com/zabisa/platform/packages/go/platform/authz"
	"github.com/zabisa/platform/packages/go/platform/router"
)

const testJWTKey = "01234567890123456789012345678901"

func token(t *testing.T, subject, role string) string {
	t.Helper()
	signed, err := auth.Sign(testJWTKey, auth.AccessClaims(subject, role, "session", time.Hour))
	if err != nil {
		t.Fatal(err)
	}
	return signed
}

func call(handler router.HandlerFunc, request *http.Request) *httptest.ResponseRecorder {
	recorder := httptest.NewRecorder()
	handler(recorder, request, map[string]string{"id": "student-1"})
	return recorder
}

func TestAuthenticatedAndPermission(t *testing.T) {
	control := Control{JWTKey: testJWTKey}
	next := func(w http.ResponseWriter, _ *http.Request, _ map[string]string) { w.WriteHeader(http.StatusNoContent) }

	request := httptest.NewRequest(http.MethodGet, "/", nil)
	if got := call(control.Authenticated(next), request).Code; got != http.StatusUnauthorized {
		t.Fatalf("anonymous status = %d", got)
	}

	request.Header.Set("Authorization", "Bearer "+token(t, "user-1", "GUARDIAN"))
	if got := call(control.Authenticated(next), request).Code; got != http.StatusNoContent {
		t.Fatalf("authenticated status = %d", got)
	}
	if got := call(control.RequirePermission(authz.AcademicsWrite, next), request).Code; got != http.StatusForbidden {
		t.Fatalf("permission status = %d", got)
	}
	request.Header.Set("Authorization", "Bearer "+token(t, "admin-1", "SUPER_ADMIN"))
	if got := call(control.RequirePermission(authz.AcademicsWrite, next), request).Code; got != http.StatusNoContent {
		t.Fatalf("authorized permission status = %d", got)
	}
}

func TestInternal(t *testing.T) {
	control := Control{InternalKey: "internal-secret"}
	next := func(w http.ResponseWriter, _ *http.Request, _ map[string]string) { w.WriteHeader(http.StatusNoContent) }
	request := httptest.NewRequest(http.MethodGet, "/", nil)
	if got := call(control.Internal(next), request).Code; got != http.StatusForbidden {
		t.Fatalf("missing key status = %d", got)
	}
	request.Header.Set("X-Internal-Key", "internal-secret")
	if got := call(control.Internal(next), request).Code; got != http.StatusNoContent {
		t.Fatalf("valid key status = %d", got)
	}
}

func TestStudentScopedGuardian(t *testing.T) {
	statusCode := http.StatusOK
	body := `{"data":{"guardian_user_ids":["guardian-1"]}}`
	studentService := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("X-Internal-Key") != "internal-secret" {
			t.Error("internal key was not forwarded")
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(statusCode)
		_, _ = w.Write([]byte(body))
	}))
	defer studentService.Close()
	control := Control{JWTKey: testJWTKey, InternalKey: "internal-secret", StudentServiceURL: studentService.URL, Client: studentService.Client()}
	next := func(w http.ResponseWriter, _ *http.Request, _ map[string]string) { w.WriteHeader(http.StatusNoContent) }
	request := httptest.NewRequest(http.MethodGet, "/", nil)
	request.Header.Set("Authorization", "Bearer "+token(t, "guardian-1", "WALI_SANTRI"))
	if got := call(control.StudentScoped(authz.AcademicsRead, next), request).Code; got != http.StatusNoContent {
		t.Fatalf("approved guardian status = %d", got)
	}

	request.Header.Del("Authorization")
	if got := call(control.StudentScoped(authz.AcademicsRead, next), request).Code; got != http.StatusUnauthorized {
		t.Fatalf("anonymous student scope status = %d", got)
	}

	request.Header.Set("Authorization", "Bearer "+token(t, "staff-1", "SUPER_ADMIN"))
	if got := call(control.StudentScoped(authz.AcademicsRead, next), request).Code; got != http.StatusNoContent {
		t.Fatalf("staff student scope status = %d", got)
	}

	request.Header.Set("Authorization", "Bearer "+token(t, "user-1", "DONOR"))
	if got := call(control.StudentScoped(authz.AcademicsRead, next), request).Code; got != http.StatusForbidden {
		t.Fatalf("non-guardian scope status = %d", got)
	}

	request.Header.Set("Authorization", "Bearer "+token(t, "guardian-2", "GUARDIAN"))
	if got := call(control.StudentScoped(authz.AcademicsRead, next), request).Code; got != http.StatusForbidden {
		t.Fatalf("unlinked guardian status = %d", got)
	}

	statusCode = http.StatusServiceUnavailable
	if got := call(control.StudentScoped(authz.AcademicsRead, next), request).Code; got != http.StatusBadGateway {
		t.Fatalf("dependency status = %d", got)
	}

	statusCode = http.StatusOK
	body = `{invalid`
	if got := call(control.StudentScoped(authz.AcademicsRead, next), request).Code; got != http.StatusBadGateway {
		t.Fatalf("invalid dependency response status = %d", got)
	}
}

func TestApprovedGuardianRequestFailures(t *testing.T) {
	control := Control{StudentServiceURL: "://invalid"}
	if _, err := control.isApprovedGuardian(context.Background(), "student-1", "guardian-1"); err == nil {
		t.Fatal("expected invalid URL error")
	}

	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	control.StudentServiceURL = "http://127.0.0.1:1"
	if _, err := control.isApprovedGuardian(ctx, "student-1", "guardian-1"); err == nil {
		t.Fatal("expected canceled request error")
	}
}
