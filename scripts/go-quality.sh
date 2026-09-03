#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

readonly REQUIRED_GO_VERSION="$(awk '/^toolchain / { sub(/^toolchain go/, ""); print; exit }' go.mod)"
readonly ACTUAL_GO_VERSION="$(go env GOVERSION | sed 's/^go//')"
readonly GO_COVER_PACKAGES="github.com/zabisa/platform/packages/go/...,github.com/zabisa/platform/services/..."
readonly GO_PACKAGES=(./packages/go/... ./services/...)

if [[ -z "$REQUIRED_GO_VERSION" ]]; then
  echo '[go-quality] ERROR: go.mod must declare an exact toolchain version.' >&2
  exit 1
fi
if [[ "$ACTUAL_GO_VERSION" != "$REQUIRED_GO_VERSION" ]]; then
  printf '[go-quality] ERROR: Go %s is required; current version is %s.\n' "$REQUIRED_GO_VERSION" "$ACTUAL_GO_VERSION" >&2
  exit 1
fi

export GOTOOLCHAIN=local
mkdir -p coverage

unformatted="$(gofmt -l services packages/go)"
if [[ -n "$unformatted" ]]; then
  printf '%s\n' "$unformatted" >&2
  echo '[go-quality] ERROR: gofmt is required.' >&2
  exit 1
fi
echo '[go-quality] PASS: gofmt'

go vet "${GO_PACKAGES[@]}"
echo '[go-quality] PASS: go vet'

if ! go test \
  -json \
  -count=1 \
  -covermode=atomic \
  -coverpkg="$GO_COVER_PACKAGES" \
  -coverprofile=coverage/go-cover.out \
  "${GO_PACKAGES[@]}" > coverage/go-test-report.json; then
  tail -n 200 coverage/go-test-report.json >&2
  echo '[go-quality] ERROR: Go tests failed.' >&2
  exit 1
fi

go tool cover -func=coverage/go-cover.out | tail -n 1
echo '[go-quality] PASS: scoped Go tests + coverage reports'
