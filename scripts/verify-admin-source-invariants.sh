#!/usr/bin/env bash
set -euo pipefail
ROOT=${ZABISA_ROOT:-$HOME/project-homelab/zabisa-super-app}
cd "$ROOT"

SOURCE_DIRS=(
  apps/admin-web/app
  apps/admin-web/components
  apps/admin-web/lib
)

for path in "${SOURCE_DIRS[@]}"; do
  [[ -d "$path" ]] || { echo "ERROR: source path tidak ditemukan: $path"; exit 2; }
done

echo "=== Admin source invariants (source only) ==="

echo "Check: no useEffect server-state loader in authored source"
# PHASE351_INTENT_AWARE_USEEFFECT
python3 - <<'PY_USEEFFECT'
from pathlib import Path
import re, sys

roots = [
    Path("apps/admin-web/app"),
    Path("apps/admin-web/components"),
    Path("apps/admin-web/lib"),
]

allowed = {
    Path("apps/admin-web/app/(protected)/error.tsx"),
}

violations = []
for root in roots:
    if not root.exists():
        continue
    for path in root.rglob("*"):
        if path.suffix not in {".ts", ".tsx"}:
            continue
        if ".next" in path.parts or "node_modules" in path.parts:
            continue
        text = path.read_text(encoding="utf-8")
        if not re.search(r"\buseEffect\b", text):
            continue

        if path in allowed:
            forbidden = (
                "fetch(",
                "request(",
                "useApiQuery",
                "useMutation",
                "queryClient.fetch",
                ".invalidateQueries(",
            )
            if any(token in text for token in forbidden):
                violations.append(
                    f"{path}: allowed useEffect contains server-state/data-loading token"
                )
            continue

        violations.append(f"{path}: useEffect is not on the reviewed side-effect allowlist")

if violations:
    print("ERROR: reviewed useEffect invariant failed:")
    for item in violations:
        print("  " + item)
    sys.exit(3)

print("PASS no useEffect server-state loaders; reviewed error-boundary telemetry side-effect allowed")
PY_USEEFFECT

echo "Check: no common explicit-any syntax in authored source"
if grep -RInE '(^|[^[:alnum:]_])(as[[:space:]]+any\b|any\[\]|<any>|:[[:space:]]*any\b|Record<[^>]*,[[:space:]]*any>)' \
  "${SOURCE_DIRS[@]}" \
  --include='*.ts' --include='*.tsx' \
  --exclude-dir='.next' --exclude-dir='node_modules'; then
  echo "ERROR: authored Backoffice source masih mengandung explicit-any syntax."
  exit 4
fi

grep -q 'QueryClientProvider' apps/admin-web/app/providers.tsx
grep -q '@tanstack/react-query' apps/admin-web/package.json
grep -q '"@typescript-eslint/no-explicit-any": "error"' apps/admin-web/eslint.config.mjs

echo "PASS authored-source boundary"
echo "Generated artifacts (.next) and dependencies (node_modules) are intentionally outside source invariants."

echo "Check: production login UI contains no development credential"
if grep -Fq 'admin@zabisa.local' apps/admin-web/app/login/LoginForm.tsx ||
  grep -Fq 'ChangeMe123!' apps/admin-web/app/login/LoginForm.tsx ||
  grep -Fq 'Development seed:' apps/admin-web/app/login/LoginForm.tsx; then
  echo "ERROR: Backoffice login UI exposes a development credential or seed hint."
  exit 5
fi
grep -Fq 'useState("")' apps/admin-web/app/login/LoginForm.tsx
echo "PASS production login fields start empty and contain no credential hint"

echo "Check: centralized auth/session query cache"
./scripts/verify-admin-session-cache.sh apps/admin-web
