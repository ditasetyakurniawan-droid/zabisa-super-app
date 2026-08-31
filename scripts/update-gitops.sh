#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
# shellcheck source=scripts/image-inventory.sh
source scripts/image-inventory.sh

SHA="${1:-}"
DEST="${2:-build/gitops-rendered}"
if [[ ! "$SHA" =~ ^[0-9a-fA-F]{12,64}$ ]]; then
  echo "ERROR: GitOps render tag must be a 12-64 character hexadecimal Git SHA." >&2
  exit 64
fi
SHA="${SHA,,}"
HARBOR="${HARBOR:-harbor-dt.co.id}"; HARBOR="${HARBOR%/}"
PROJECT="${PROJECT:-zabisa}"; PROJECT="${PROJECT#/}"; PROJECT="${PROJECT%/}"

if [[ "$DEST" != /* ]]; then DEST="$ROOT/$DEST"; fi
rm -rf "$DEST"
mkdir -p "$DEST"
cp -a deploy/kubernetes/base/. "$DEST/"

replacements=0
for name in "${ZABISA_IMAGE_NAMES[@]}"; do
  old="harbor-dt.co.id/zabisa/${name}:REPLACE_SHA"
  new="${HARBOR}/${PROJECT}/${name}:${SHA}"
  expected="$(zabisa_expected_manifest_refs_for "$name")"
  count="$( (grep -RhF -o "$old" "$DEST" 2>/dev/null || true) | wc -l | tr -d ' ')"
  if [[ "$count" != "$expected" ]]; then
    echo "ERROR: expected ${expected} placeholder image reference(s) for $name; found $count." >&2
    exit 1
  fi
  while IFS= read -r -d '' file; do
    sed -i "s#${old}#${new}#g" "$file"
  done < <(grep -RlZF "$old" "$DEST" 2>/dev/null || true)
  replacements=$((replacements + count))
done

if grep -RIn --include='*.yaml' --include='*.yml' 'REPLACE_SHA\|:latest\([[:space:]]\|$\)' "$DEST"; then
  echo 'ERROR: rendered GitOps output still contains REPLACE_SHA or :latest.' >&2
  exit 1
fi

expected_total=0
for name in "${ZABISA_IMAGE_NAMES[@]}"; do
  expected_total=$((expected_total + $(zabisa_expected_manifest_refs_for "$name")))
done
actual="$(grep -Rh --include='*.yaml' --include='*.yml' -E '^[[:space:]]*image:[[:space:]]+harbor-dt\.co\.id/zabisa/' "$DEST" | wc -l | tr -d ' ')"
if [[ "$actual" != "$expected_total" ]]; then
  echo "ERROR: expected ${expected_total} rendered Zabisa workload image references, found $actual." >&2
  exit 1
fi

printf '[gitops] PASS: rendered %d immutable image references across %d image targets into %s\n' "$replacements" "${#ZABISA_IMAGE_NAMES[@]}" "$DEST"
echo '[gitops] NOTE: this renders deployable manifests only; it does not commit/push a GitOps repository.'
