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
	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()

			recorder := httptest.NewRecorder()
			request := httptest.NewRequest(http.MethodGet, tt.path, nil)
			handler.ServeHTTP(recorder, request)

			if recorder.Code != tt.wantStatus {
				t.Fatalf("status = %d, want %d; body = %s", recorder.Code, tt.wantStatus, recorder.Body.String())
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
			if response.Data.Status != tt.wantHealth {
				t.Fatalf("health status = %q, want %q", response.Data.Status, tt.wantHealth)
			}
		})
	}
}
