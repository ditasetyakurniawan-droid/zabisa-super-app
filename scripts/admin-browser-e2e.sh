#!/usr/bin/env bash
set -euo pipefail

REPO="${ZABISA_REPO:-$HOME/project-homelab/zabisa-super-app}"
cd "$REPO"

if [ -z "${ZABISA_CHROME_BIN:-}" ]; then
  for candidate in google-chrome google-chrome-stable chromium chromium-browser; do
    if command -v "$candidate" >/dev/null 2>&1; then
      export ZABISA_CHROME_BIN="$(command -v "$candidate")"
      break
    fi
  done
fi

if [ -z "${ZABISA_CHROME_BIN:-}" ] || [ ! -x "$ZABISA_CHROME_BIN" ]; then
  echo "ERROR: system Chrome/Chromium not found. Set ZABISA_CHROME_BIN to an executable browser path."
  exit 2
fi

echo "Browser: $ZABISA_CHROME_BIN"
npm run e2e --workspace=@zabisa/admin-web
