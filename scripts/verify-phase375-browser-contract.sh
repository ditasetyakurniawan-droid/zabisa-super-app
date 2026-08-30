#!/usr/bin/env bash
set -euo pipefail
ROOT="${1:-apps/admin-web}"

python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
kajian = (root / "app/(protected)/kajian/page.tsx").read_text()
e2e = (root / "e2e/admin-navigation.spec.ts").read_text()

assert '{key: "slug", label: "Slug"}' in kajian, "Kajian table must expose slug"
assert 'has: page.getByRole("heading", {name: "Catat kehadiran"})' in e2e, "Attendance E2E must scope to attendance card"
assert 'attendanceCard.getByLabel("Santri", {exact: true})' in e2e, "Attendance selector must use exact Santri label"
assert 'page.getByLabel("Santri");' not in e2e, "Ambiguous unscoped Santri selector remains"

print("PASS Kajian list exposes operational slug")
print("PASS Attendance Browser E2E scopes Santri selector to form card")
print("PASS Attendance Browser E2E uses exact accessible label")
PY
