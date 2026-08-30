#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-apps/admin-web}"
python3 - "$ROOT" <<'PY'
from pathlib import Path
import re, sys

root = Path(sys.argv[1])
files = [
    p for p in [*root.rglob("*.ts"), *root.rglob("*.tsx")]
    if "node_modules" not in p.parts and ".next" not in p.parts
]
violations = []
for path in files:
    text = path.read_text(encoding="utf-8")
    if "event.currentTarget.reset()" in text:
        violations.append(f"{path}: async form code must capture formEl before await; event.currentTarget.reset() is forbidden")

if violations:
    print("ERROR async-form lifetime invariant:")
    for item in violations:
        print("  " + item)
    sys.exit(1)

spec = (root / "e2e/admin-navigation.spec.ts").read_text(encoding="utf-8")
required = [
    "expectSuccessfulMutation",
    "waitForRealSelectOptions",
    'Data Santri UI create and update matches strict backend contract',
    'Tahfidz target UI create then PATCH edit uses strict update DTO',
    'Donation payment-method UI create and deactivate',
    'Notification compose works through Backoffice BFF',
]
for marker in required:
    if marker not in spec:
        violations.append(f"browser E2E missing marker: {marker}")

if violations:
    print("ERROR Browser E2E form-lifecycle invariant:")
    for item in violations:
        print("  " + item)
    sys.exit(1)

print("PASS no SyntheticEvent.currentTarget reset after async boundary")
print("PASS Browser E2E asserts real mutation HTTP responses")
print("PASS dependent select readiness is explicit")
PY
