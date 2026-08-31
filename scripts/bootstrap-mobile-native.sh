#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"
npx @react-native-community/cli@20.2.0 init ZabisaMobile --version 0.87.0 --package-name id.or.subulussalam.zabisa
rsync -a --delete ZabisaMobile/android/ "$ROOT/apps/mobile/android/"
rsync -a --delete ZabisaMobile/ios/ "$ROOT/apps/mobile/ios/"
cp ZabisaMobile/babel.config.js "$ROOT/apps/mobile/" || true
cp ZabisaMobile/metro.config.js "$ROOT/apps/mobile/" || true
cp ZabisaMobile/app.json "$ROOT/apps/mobile/" || true
printf '%s\n' "Native scaffold generated for React Native 0.87.0. App source and custom index.js were preserved."
printf '%s\n' "Next: npm ci --workspaces --include-workspace-root --no-audit --no-fund && cd apps/mobile && npm run android"
