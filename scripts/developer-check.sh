#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

mode="${1:-quick}"

fail() {
  printf '[developer-check] ERROR: %s\n' "$*" >&2
  exit 1
}

command -v node >/dev/null 2>&1 || fail 'Node.js tidak ditemukan (gunakan Node 22 atau lebih baru)'
command -v npm >/dev/null 2>&1 || fail 'npm tidak ditemukan'
[[ -d node_modules ]] || fail 'node_modules belum ada; jalankan npm ci --workspaces --include-workspace-root --no-audit --no-fund'

export CI=true
export NEXT_TELEMETRY_DISABLED=1

case "$mode" in
  quick)
    echo '===== LANGKAH 1/2: PREFLIGHT DAN KONTRAK REPOSITORY ====='
    npm run node:lock:verify
    ./scripts/preflight-offline.sh

    echo '===== LANGKAH 2/2: SOURCE ADMIN DAN MOBILE ====='
    npm run lint --workspace=@zabisa/admin-web -- --max-warnings=0
    npm run typecheck --workspace=@zabisa/admin-web
    npm run test --workspace=@zabisa/admin-web
    npm run lint --workspace=@zabisa/mobile -- --max-warnings=0
    npm run typecheck --workspace=@zabisa/mobile
    npm run test --workspace=@zabisa/mobile
    git diff --check

    echo '[developer-check] PASS: pemeriksaan cepat selesai; lanjutkan mode full sebelum push.'
    ;;
  full)
    command -v go >/dev/null 2>&1 || fail 'Go tidak ditemukan (ikuti versi pada go.mod)'
    echo '===== GATE LOKAL LENGKAP (SETARA RUN REPOSITORY QUALITY GATE) ====='
    ./scripts/quality-gate.sh
    echo '[developer-check] PASS: gate lokal lengkap selesai; review diff sebelum push.'
    ;;
  *)
    echo 'Penggunaan: ./scripts/developer-check.sh [quick|full]' >&2
    exit 64
    ;;
esac
