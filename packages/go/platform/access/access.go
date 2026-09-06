package access

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/zabisa/platform/packages/go/platform/auth"
	"github.com/zabisa/platform/packages/go/platform/authz"
	"github.com/zabisa/platform/packages/go/platform/httpx"
	"github.com/zabisa/platform/packages/go/platform/router"
)

const defaultStudentServiceURL = "http://student:8083"

// Control centralizes HTTP authentication and authorization for the services.
type Control struct {
	JWTKey            string
	InternalKey       string
	StudentServiceURL string
	Client            *http.Client
}

func (c Control) Claims(r *http.Request) (auth.Claims, error) {
	raw := strings.TrimSpace(strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer "))
	return auth.Verify(c.JWTKey, raw)
}

func (c Control) Authenticated(next router.HandlerFunc) router.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request, params map[string]string) {
		if _, err := c.Claims(r); err != nil {
			httpx.Fail(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "Authentication required")
			return
		}
		next(w, r, params)
	}
}

func (c Control) RequirePermission(permission authz.Permission, next router.HandlerFunc) router.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request, params map[string]string) {
		claims, err := c.Claims(r)
		if err != nil {
			httpx.Fail(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "Authentication required")
			return
		}
		if !authz.Has(claims.Role, permission) {
			httpx.Fail(w, r, http.StatusForbidden, "FORBIDDEN", "Insufficient permission")
			return
		}
		next(w, r, params)
	}
}

func (c Control) Internal(next router.HandlerFunc) router.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request, params map[string]string) {
		if c.InternalKey == "" || r.Header.Get("X-Internal-Key") != c.InternalKey {
			httpx.Fail(w, r, http.StatusForbidden, "FORBIDDEN", "Invalid service credential")
			return
		}
		next(w, r, params)
	}
}

// StudentScoped permits staff with the requested permission or an approved
// guardian relationship for the student identified by the route's {id} value.
func (c Control) StudentScoped(permission authz.Permission, next router.HandlerFunc) router.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request, params map[string]string) {
		claims, err := c.Claims(r)
		if err != nil {
			httpx.Fail(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "Authentication required")
			return
		}
		if authz.Has(claims.Role, permission) {
			next(w, r, params)
			return
		}
		role := authz.NormalizeRole(claims.Role)
		if role != "GUARDIAN" && role != "WALI_SANTRI" {
			httpx.Fail(w, r, http.StatusForbidden, "FORBIDDEN", "Insufficient permission")
			return
		}
		approved, err := c.isApprovedGuardian(r.Context(), params["id"], claims.Sub)
		if err != nil {
			httpx.Fail(w, r, http.StatusBadGateway, "DEPENDENCY_FAILED", "Could not verify student relationship")
			return
		}
		if !approved {
			httpx.Fail(w, r, http.StatusForbidden, "FORBIDDEN", "Student is not linked to this guardian")
			return
		}
		next(w, r, params)
	}
}

func (c Control) isApprovedGuardian(ctx context.Context, studentID, userID string) (bool, error) {
	baseURL := strings.TrimRight(c.StudentServiceURL, "/")
	if baseURL == "" {
		baseURL = defaultStudentServiceURL
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, baseURL+"/internal/v1/students/"+studentID+"/guardians", nil)
	if err != nil {
		return false, err
	}
	req.Header.Set("X-Internal-Key", c.InternalKey)
	client := c.Client
	if client == nil {
		client = &http.Client{Timeout: 5 * time.Second}
	}
	res, err := client.Do(req)
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
	for _, guardianID := range envelope.Data.GuardianUserIDs {
		if guardianID == userID {
			return true, nil
		}
	}
	return false, nil
}
