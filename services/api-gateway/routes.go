package main

import (
	"log/slog"
	"net/http"
	"net/http/httputil"
	"net/url"
	"strings"

	"github.com/zabisa/platform/packages/go/platform/httpx"
)

type target struct {
	prefix  string
	handler http.Handler
}

func defaultTargets() []target {
	return []target{
		// Identity and access management.
		mustTarget("/api/v1/auth", "http://identity:8081"),
		mustTarget("/api/v1/admin/guardian-candidates", "http://identity:8081"),
		mustTarget("/api/v1/admin/notification-candidates", "http://identity:8081"),
		mustTarget("/api/v1/admin/users", "http://identity:8081"),
		mustTarget("/api/v1/admin/audit-logs", "http://identity:8081"),

		// Public content and Kajian management.
		mustTarget("/api/v1/kajian", "http://content:8082"),
		mustTarget("/api/v1/content", "http://content:8082"),
		mustTarget("/api/v1/admin/kajian", "http://content:8082"),
		mustTarget("/api/v1/admin/content", "http://content:8082"),

		// Student, guardian, and attendance management.
		mustTarget("/api/v1/guardian", "http://student:8083"),
		mustTarget("/api/v1/admin/students", "http://student:8083"),
		mustTarget("/api/v1/admin/guardian-links", "http://student:8083"),
		mustTarget("/api/v1/admin/attendance", "http://student:8083"),

		// Tahfidz and academic records.
		mustTarget("/api/v1/tahfidz", "http://tahfidz:8084"),
		mustTarget("/api/v1/subjects", "http://academic:8085"),
		mustTarget("/api/v1/grades", "http://academic:8085"),
		mustTarget("/api/v1/students", "http://academic:8085"),
		mustTarget("/api/v1/admin/subjects", "http://academic:8085"),
		mustTarget("/api/v1/admin/grades", "http://academic:8085"),
		mustTarget("/api/v1/admin/reports", "http://academic:8085"),

		// Donation workflows.
		mustTarget("/api/v1/donation", "http://donation:8086"),
		mustTarget("/api/v1/donations", "http://donation:8086"),
		mustTarget("/api/v1/admin/donation", "http://donation:8086"),
		mustTarget("/api/v1/admin/donations", "http://donation:8086"),

		// Notification inbox and device registration.
		mustTarget("/api/v1/notifications", "http://notification:8087"),
		mustTarget("/api/v1/devices", "http://notification:8087"),
		mustTarget("/api/v1/admin/notifications", "http://notification:8087"),
	}
}

func mustTarget(prefix, rawURL string) target {
	upstreamURL, err := url.Parse(rawURL)
	if err != nil {
		panic(err)
	}

	proxy := httputil.NewSingleHostReverseProxy(upstreamURL)
	proxy.ErrorHandler = func(w http.ResponseWriter, r *http.Request, proxyErr error) {
		slog.Error("upstream failure", "error", proxyErr, "path", r.URL.Path)
		httpx.Fail(w, r, http.StatusBadGateway, "UPSTREAM_UNAVAILABLE", "Service temporarily unavailable")
	}

	return target{prefix: strings.TrimSuffix(prefix, "/"), handler: proxy}
}

func (t target) matches(path string) bool {
	return path == t.prefix || strings.HasPrefix(path, t.prefix+"/")
}
