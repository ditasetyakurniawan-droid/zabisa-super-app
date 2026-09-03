package main

import (
	"context"
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"github.com/zabisa/platform/packages/go/platform/auth"
	"github.com/zabisa/platform/packages/go/platform/authz"
	"github.com/zabisa/platform/packages/go/platform/config"
)

const (
	identityServiceURL = "http://identity:8081"
	studentServiceURL  = "http://student:8083"
)

type guardianStudentsEnvelope struct {
	Data []struct {
		ID string `json:"id"`
	} `json:"data"`
}

type sessionStatusEnvelope struct {
	Data struct {
		Active bool   `json:"active"`
		UserID string `json:"user_id"`
		Role   string `json:"role"`
	} `json:"data"`
}

func protectedStudentPath(path string) bool {
	return strings.HasPrefix(path, "/api/v1/tahfidz/students/") ||
		(strings.HasPrefix(path, "/api/v1/students/") &&
			(strings.HasSuffix(path, "/grades") || strings.HasSuffix(path, "/reports")))
}

func guardianObjectAccess(cfg config.Config, r *http.Request) bool {
	claims, err := auth.Verify(cfg.JWTKey, bearerToken(r))
	if err != nil {
		return false
	}
	if claims.Role != "GUARDIAN" && claims.Role != "WALI_SANTRI" {
		return true
	}

	studentID := studentIDFromPath(r.URL.Path)
	if studentID == "" {
		return false
	}

	req, err := http.NewRequestWithContext(r.Context(), http.MethodGet, studentServiceURL+"/api/v1/guardian/students", nil)
	if err != nil {
		return false
	}
	req.Header.Set("Authorization", r.Header.Get("Authorization"))

	res, err := (&http.Client{Timeout: 4 * time.Second}).Do(req)
	if err != nil {
		return false
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		return false
	}

	var body guardianStudentsEnvelope
	if err := json.NewDecoder(res.Body).Decode(&body); err != nil {
		return false
	}
	for _, student := range body.Data {
		if student.ID == studentID {
			return true
		}
	}
	return false
}

func studentIDFromPath(path string) string {
	parts := strings.Split(strings.Trim(path, "/"), "/")
	for index, part := range parts {
		if part == "students" && index+1 < len(parts) {
			return parts[index+1]
		}
	}
	return ""
}

func activeSession(ctx context.Context, cfg config.Config, claims auth.Claims) (active bool, dependencyAvailable bool) {
	if claims.SessionID == "" {
		return false, true
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, identityServiceURL+"/internal/v1/sessions/"+claims.SessionID, nil)
	if err != nil {
		return false, false
	}
	req.Header.Set("X-Internal-Key", cfg.InternalServiceKey)

	res, err := (&http.Client{Timeout: 2 * time.Second}).Do(req)
	if err != nil {
		return false, false
	}
	defer res.Body.Close()
	if res.StatusCode == http.StatusNotFound {
		return false, true
	}
	if res.StatusCode != http.StatusOK {
		return false, false
	}

	var body sessionStatusEnvelope
	if err := json.NewDecoder(res.Body).Decode(&body); err != nil {
		return false, false
	}
	if !body.Data.Active || body.Data.UserID != claims.Sub {
		return false, true
	}

	// Reject a stale JWT immediately after an administrator changes the role.
	if authz.NormalizeRole(body.Data.Role) != authz.NormalizeRole(claims.Role) {
		return false, true
	}
	return true, true
}
