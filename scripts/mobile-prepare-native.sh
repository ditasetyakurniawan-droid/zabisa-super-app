#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOBILE="$ROOT/apps/mobile"

CODEGEN="$(dirname "$(node -p "require.resolve('@react-native/codegen/package.json',{paths:['$MOBILE']})")")"

mkdir -p "$MOBILE/node_modules/@react-native"
rm -rf "$MOBILE/node_modules/@react-native/codegen"
ln -s "$CODEGEN" "$MOBILE/node_modules/@react-native/codegen"

TARGET="$MOBILE/node_modules/@react-native/codegen/lib/cli/combine/combine-js-to-schema-cli.js"

test -f "$TARGET" || {
  echo "ERROR: React Native Codegen CLI tidak ditemukan: $TARGET"
  exit 1
}

echo "Native workspace dependencies OK"
echo "Codegen: $CODEGEN"
