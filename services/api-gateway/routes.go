package main

import (
	"log/slog"
	"net/http"
	"net/http/httputil"
	"net/url"
	"strings"

	"github.com/zabisa/platform/packages/go/platform/httpx"
)

const (
	identityTarget     = "http://identity:8081"
	contentTarget      = "http://content:8082"
	studentTarget      = "http://student:8083"
	academicTarget     = "http://academic:8085"
	donationTarget     = "http://donation:8086"
	notificationTarget = "http://notification:8087"
)

type target struct {
	prefix  string
	handler http.Handler
}

func defaultTargets() []target {
	return []target{
		// Identity and access management.
		mustTarget("/api/v1/auth", identityTarget),
		mustTarget("/api/v1/admin/guardian-candidates", identityTarget),
		mustTarget("/api/v1/admin/notification-candidates", identityTarget),
		mustTarget("/api/v1/admin/users", identityTarget),
		mustTarget("/api/v1/admin/audit-logs", identityTarget),

		// Public content and Kajian management.
		mustTarget("/api/v1/kajian", contentTarget),
		mustTarget("/api/v1/content", contentTarget),
		mustTarget("/api/v1/admin/kajian", contentTarget),
		mustTarget("/api/v1/admin/content", contentTarget),

		// Student, guardian, and attendance management.
		mustTarget("/api/v1/guardian", studentTarget),
		mustTarget("/api/v1/admin/students", studentTarget),
		mustTarget("/api/v1/admin/guardian-links", studentTarget),
		mustTarget("/api/v1/admin/attendance", studentTarget),

		// Tahfidz and academic records.
		mustTarget("/api/v1/tahfidz", "http://tahfidz:8084"),
		mustTarget("/api/v1/subjects", academicTarget),
		mustTarget("/api/v1/grades", academicTarget),
		mustTarget("/api/v1/students", academicTarget),
		mustTarget("/api/v1/admin/subjects", academicTarget),
		mustTarget("/api/v1/admin/grades", academicTarget),
		mustTarget("/api/v1/admin/reports", academicTarget),

		// Donation workflows.
		mustTarget("/api/v1/donation", donationTarget),
		mustTarget("/api/v1/donations", donationTarget),
		mustTarget("/api/v1/admin/donation", donationTarget),
		mustTarget("/api/v1/admin/donations", donationTarget),

		// Notification inbox and device registration.
		mustTarget("/api/v1/notifications", notificationTarget),
		mustTarget("/api/v1/devices", notificationTarget),
		mustTarget("/api/v1/admin/notifications", notificationTarget),
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
