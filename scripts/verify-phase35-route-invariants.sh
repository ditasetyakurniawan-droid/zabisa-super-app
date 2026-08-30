#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from pathlib import Path
import sys

checks = {
    Path("services/donation/main.go"): [
        '\trt.Handle("GET", "/api/v1/admin/donation/campaigns", a.requirePermission(authz.DonationRead, a.listCampaignsAdmin))',
        '\trt.Handle("PATCH", "/api/v1/admin/donation/campaigns/{id}", a.requirePermission(authz.DonationWrite, a.updateCampaign))',
        '\trt.Handle("POST", "/api/v1/admin/donation/campaigns/{id}/updates", a.requirePermission(authz.DonationWrite, a.createCampaignUpdate))',
        '\trt.Handle("PATCH", "/api/v1/admin/donation/payment-methods/{id}", a.requirePermission(authz.DonationWrite, a.updatePaymentMethod))',
        '\trt.Handle("PATCH", "/api/v1/admin/donations/{id}/verify", a.requirePermission(authz.DonationVerify, a.verifyDonation))',
    ],
}

failed = False
for path, routes in checks.items():
    text = path.read_text()
    for route in routes:
        count = text.count(route)
        if count != 1:
            print(f"ERROR {path}: exact route count={count}: {route.strip()}")
            failed = True
        else:
            print(f"PASS {path}: {route.strip()}")

if failed:
    sys.exit(1)

print("PASS Phase 3.5 exact route invariants")
PY
