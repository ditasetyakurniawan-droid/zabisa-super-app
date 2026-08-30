package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/zabisa/platform/packages/go/platform/authz"
	"github.com/zabisa/platform/packages/go/platform/httpx"
	"github.com/zabisa/platform/packages/go/platform/router"
)

func (a *app) studentScoped(permission authz.Permission, h router.HandlerFunc) router.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request, p map[string]string) {
		claims, err := a.claims(r)
		if err != nil {
			httpx.Fail(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "Authentication required")
			return
		}
		if authz.Has(claims.Role, permission) {
			h(w, r, p)
			return
		}
		role := authz.NormalizeRole(claims.Role)
		if role != "GUARDIAN" && role != "WALI_SANTRI" {
			httpx.Fail(w, r, http.StatusForbidden, "FORBIDDEN", "Insufficient permission")
			return
		}
		ok, err := a.isApprovedGuardian(r.Context(), p["id"], claims.Sub)
		if err != nil {
			httpx.Fail(w, r, http.StatusBadGateway, "DEPENDENCY_FAILED", "Could not verify student relationship")
			return
		}
		if !ok {
			httpx.Fail(w, r, http.StatusForbidden, "FORBIDDEN", "Student is not linked to this guardian")
			return
		}
		h(w, r, p)
	}
}

func (a *app) isApprovedGuardian(ctx context.Context, studentID, userID string) (bool, error) {
	base := strings.TrimRight(envURL("STUDENT_SERVICE_URL", "http://student:8083"), "/")
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, base+"/internal/v1/students/"+studentID+"/guardians", nil)
	if err != nil {
		return false, err
	}
	req.Header.Set("X-Internal-Key", a.cfg.InternalServiceKey)
	res, err := (&http.Client{Timeout: 5 * time.Second}).Do(req)
	if err != nil {
		return false, err
	}
	defer res.Body.Close()
	body, err := io.ReadAll(io.LimitReader(res.Body, 1<<20))
	if err != nil {
		return false, err
	}
	if res.StatusCode != http.StatusOK {
		return false, fmt.Errorf("student service status %d", res.StatusCode)
	}
	var envelope struct {
		Data struct {
			GuardianUserIDs []string `json:"guardian_user_ids"`
		} `json:"data"`
	}
	if err := json.Unmarshal(body, &envelope); err != nil {
		return false, err
	}
	for _, id := range envelope.Data.GuardianUserIDs {
		if id == userID {
			return true, nil
		}
	}
	return false, nil
}
