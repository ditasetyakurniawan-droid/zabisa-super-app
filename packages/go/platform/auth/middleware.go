package auth

import (
	"context"
	"github.com/zabisa/platform/packages/go/platform/httpx"
	"net/http"
	"strings"
)

type contextKey string

const claimsKey contextKey = "claims"

func ClaimsFrom(ctx context.Context) (Claims, bool) {
	c, ok := ctx.Value(claimsKey).(Claims)
	return c, ok
}
func Require(key string, roles ...string) func(http.Handler) http.Handler {
	allowed := map[string]bool{}
	for _, r := range roles {
		allowed[r] = true
	}
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			raw := strings.TrimSpace(strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer "))
			c, err := Verify(key, raw)
			if err != nil {
				httpx.Fail(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "Authentication required")
				return
			}
			if len(allowed) > 0 && !allowed[c.Role] {
				httpx.Fail(w, r, http.StatusForbidden, "FORBIDDEN", "Insufficient permission")
				return
			}
			next.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), claimsKey, c)))
		})
	}
}
