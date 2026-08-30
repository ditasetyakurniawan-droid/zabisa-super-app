package health

import (
	"database/sql"
	"github.com/zabisa/platform/packages/go/platform/httpx"
	"net/http"
)

func Live(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	httpx.JSON(w, http.StatusOK, map[string]string{"status": "ok"})
}
func Ready(db *sql.DB) func(http.ResponseWriter, *http.Request, map[string]string) {
	return func(w http.ResponseWriter, r *http.Request, _ map[string]string) {
		if err := db.PingContext(r.Context()); err != nil {
			httpx.Fail(w, r, http.StatusServiceUnavailable, "NOT_READY", "Database unavailable")
			return
		}
		httpx.JSON(w, http.StatusOK, map[string]string{"status": "ready"})
	}
}
