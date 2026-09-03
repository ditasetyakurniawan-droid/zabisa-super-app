package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/zabisa/platform/packages/go/platform/config"
)

func TestGatewayHealthEndpoints(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name       string
		path       string
		wantStatus int
		wantHealth string
	}{
		{name: "liveness", path: "/health/live", wantStatus: http.StatusOK, wantHealth: "ok"},
		{name: "readiness", path: "/health/ready", wantStatus: http.StatusOK, wantHealth: "ready"},
	}

	handler := newGatewayHandler(config.Config{}, nil)
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			t.Parallel()

			recorder := httptest.NewRecorder()
			request := httptest.NewRequest(http.MethodGet, test.path, nil)
			handler.ServeHTTP(recorder, request)

			if recorder.Code != test.wantStatus {
				t.Fatalf("status = %d, want %d; body = %s", recorder.Code, test.wantStatus, recorder.Body.String())
			}
			if contentType := recorder.Header().Get("Content-Type"); contentType != "application/json; charset=utf-8" {
				t.Fatalf("Content-Type = %q, want application/json; charset=utf-8", contentType)
			}

			var response struct {
				Data struct {
					Status string `json:"status"`
				} `json:"data"`
				Error any `json:"error"`
			}
			if err := json.NewDecoder(recorder.Body).Decode(&response); err != nil {
				t.Fatalf("decode response: %v", err)
			}
			if response.Error != nil {
				t.Fatalf("error = %#v, want nil", response.Error)
			}
			if response.Data.Status != test.wantHealth {
				t.Fatalf("health status = %q, want %q", response.Data.Status, test.wantHealth)
			}
		})
	}
}

func TestGatewayRoutesOnlyOnPathBoundary(t *testing.T) {
	t.Parallel()

	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusNoContent)
	}))
	t.Cleanup(upstream.Close)

	handler := newGatewayHandler(config.Config{}, []target{mustTarget("/api/v1/content", upstream.URL)})
	tests := []struct {
		name       string
		path       string
		wantStatus int
	}{
		{name: "exact route", path: "/api/v1/content", wantStatus: http.StatusNoContent},
		{name: "nested route", path: "/api/v1/content/article-1", wantStatus: http.StatusNoContent},
		{name: "similar prefix", path: "/api/v1/contentious", wantStatus: http.StatusNotFound},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			t.Parallel()

			recorder := httptest.NewRecorder()
			request := httptest.NewRequest(http.MethodGet, test.path, nil)
			handler.ServeHTTP(recorder, request)
			if recorder.Code != test.wantStatus {
				t.Fatalf("status = %d, want %d; body = %s", recorder.Code, test.wantStatus, recorder.Body.String())
			}
		})
	}
}

func TestProtectedStudentPath(t *testing.T) {
	t.Parallel()

	tests := []struct {
		path string
		want bool
	}{
		{path: "/api/v1/tahfidz/students/student-1/entries", want: true},
		{path: "/api/v1/students/student-1/grades", want: true},
		{path: "/api/v1/students/student-1/reports", want: true},
		{path: "/api/v1/students/student-1", want: false},
		{path: "/api/v1/kajian", want: false},
	}

	for _, test := range tests {
		if got := protectedStudentPath(test.path); got != test.want {
			t.Errorf("protectedStudentPath(%q) = %t, want %t", test.path, got, test.want)
		}
	}
}

func TestStudentIDFromPath(t *testing.T) {
	t.Parallel()

	tests := []struct {
		path string
		want string
	}{
		{path: "/api/v1/students/student-1/grades", want: "student-1"},
		{path: "/api/v1/tahfidz/students/student-2/entries", want: "student-2"},
		{path: "/api/v1/students", want: ""},
	}

	for _, test := range tests {
		if got := studentIDFromPath(test.path); got != test.want {
			t.Errorf("studentIDFromPath(%q) = %q, want %q", test.path, got, test.want)
		}
	}
}
