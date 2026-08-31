#!/usr/bin/env bash
# Shared immutable image inventory for build, verification and GitOps rendering.
# Source this file; do not execute it directly for side effects.

ZABISA_IMAGE_NAMES=(
  api-gateway
  identity
  content
  student
  tahfidz
  academic
  donation
  notification
  admin-web
)

zabisa_dockerfile_for() {
  case "$1" in
    admin-web) printf '%s\n' 'apps/admin-web/Dockerfile' ;;
    api-gateway|identity|content|student|tahfidz|academic|donation|notification)
      printf 'services/%s/Dockerfile\n' "$1"
      ;;
    *) return 1 ;;
  esac
}

zabisa_manifest_for() {
  case "$1" in
    admin-web) printf '%s\n' 'admin-web.yaml' ;;
    api-gateway|identity|content|student|tahfidz|academic|donation|notification)
      printf '%s.yaml\n' "$1"
      ;;
    *) return 1 ;;
  esac
}

# Runtime manifests use every image once. Stateful service images are also
# reused by one ArgoCD PreSync migration Job.
zabisa_expected_manifest_refs_for() {
  case "$1" in
    identity|content|student|tahfidz|academic|donation|notification) printf '%s\n' '2' ;;
    api-gateway|admin-web) printf '%s\n' '1' ;;
    *) return 1 ;;
  esac
}
