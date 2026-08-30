#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from pathlib import Path
import re, sys

checks=[]
def need(path, pattern, label, regex=False):
    text=Path(path).read_text()
    ok=bool(re.search(pattern,text,re.S)) if regex else pattern in text
    checks.append((ok,label))

def forbid(path, pattern, label, regex=False):
    text=Path(path).read_text()
    found=bool(re.search(pattern,text,re.S)) if regex else pattern in text
    checks.append((not found,label))

# Strict JSON remains a backend invariant.
need('packages/go/platform/httpx/httpx.go','DisallowUnknownFields','strict JSON decoder rejects unknown fields')

# Student form/body contract.
student='services/student/main.go'
for field in ['PhotoURL     string `json:"photo_url"`','Status       string `json:"status"`']:
    need(student,field,f'student create DTO includes {field.split("json:")[1]}')
need('apps/admin-web/app/(protected)/students/page.tsx','{name: "photo_url", label: "URL foto"}','student UI includes photo_url')
need('apps/admin-web/app/(protected)/students/page.tsx','name: "status"','student UI includes status')

# Tahfidz target immutable ownership.
need('services/tahfidz/operational_admin.go','type updateTargetIn struct','dedicated Tahfidz target update DTO')
forbid('services/tahfidz/operational_admin.go','StudentID  string','Tahfidz target PATCH DTO excludes student_id')
need('apps/admin-web/app/(protected)/tahfidz/page.tsx','const updatePayload = {','Tahfidz UI has separate update payload')
need('apps/admin-web/app/(protected)/tahfidz/page.tsx','body: JSON.stringify(editingTarget ? updatePayload : createPayload)','Tahfidz UI separates POST/PATCH DTO')

# Donation payment-method create/update split.
need('services/donation/main.go','type paymentAccountIn struct','payment method create DTO exists')
need('services/donation/operational_admin.go','type updatePaymentAccountIn struct','payment method update DTO exists')
need('apps/admin-web/app/(protected)/donation/page.tsx','const basePayload = {','payment method create payload excludes lifecycle flag')
need('apps/admin-web/app/(protected)/donation/page.tsx','const updatePayload = {...basePayload, active:','payment method PATCH adds active lifecycle flag')

# Least-privilege candidate directories.
need('services/identity/main.go','/api/v1/admin/guardian-candidates','guardian candidate endpoint registered')
need('services/identity/main.go','authz.GuardiansRead','guardian candidate endpoint uses guardians.read')
need('services/identity/main.go','/api/v1/admin/notification-candidates','notification candidate endpoint registered')
need('services/identity/main.go','authz.NotificationsRead','notification candidate endpoint uses notifications.read')
need('services/api-gateway/main.go','/api/v1/admin/guardian-candidates','gateway routes guardian candidates')
need('services/api-gateway/main.go','/api/v1/admin/notification-candidates','gateway routes notification candidates')
need('apps/admin-web/app/(protected)/guardians/page.tsx','/v1/admin/guardian-candidates','guardian UI uses narrow candidate endpoint')
forbid('apps/admin-web/app/(protected)/guardians/page.tsx','useApiQuery<AdminUser[]>("/v1/admin/users")','guardian UI does not require broad users.read')
need('apps/admin-web/app/(protected)/notifications/page.tsx','/v1/admin/notification-candidates','notification UI uses narrow audience endpoint')
forbid('apps/admin-web/app/(protected)/notifications/page.tsx','useApiQuery<AdminUser[]>("/v1/admin/users")','notification UI does not require broad users.read')

# UI permission boundary.
need('apps/admin-web/components/EditableResourcePage.tsx','canWrite = true','editable resource supports explicit read-only mode')
need('apps/admin-web/app/(protected)/students/page.tsx','permissions.studentsWrite','student UI controls mutations with students.write')
need('apps/admin-web/app/(protected)/academics/page.tsx','permissions.academicsWrite','academic UI controls mutations with academics.write')
need('apps/admin-web/app/(protected)/academics/page.tsx','permissions.academicsPublish','academic publish controls use academics.publish')
need('apps/admin-web/app/(protected)/notifications/page.tsx','permissions.notificationsWrite','notification UI controls compose with notifications.write')

# Local cookie policy and BFF correlation propagation.
need('docker-compose.yml','ZABISA_COOKIE_SECURE: "false"','local Compose explicitly disables Secure cookie over HTTP')
need('apps/admin-web/lib/server.ts','ZABISA_COOKIE_SECURE','cookie security is environment-configurable')
need('apps/admin-web/app/api/backend/[...path]/route.ts','traceparent','BFF propagates traceparent')
need('apps/admin-web/app/api/backend/[...path]/route.ts','x-request-id','BFF propagates request correlation')

# Audit/outbox coverage markers.
actions={
 'services/student/main.go':['STUDENT_CREATED','GUARDIAN_LINK_REQUESTED','GUARDIAN_LINK_APPROVED','ATTENDANCE_UPSERTED'],
 'services/student/operational_admin.go':['STUDENT_UPDATED','GUARDIAN_LINK_REJECTED','GUARDIAN_LINK_REVOKED'],
 'services/tahfidz/main.go':['TAHFIDZ_ENTRY_CREATED'],
 'services/tahfidz/admin_extra.go':['TAHFIDZ_TARGET_CREATED'],
 'services/tahfidz/operational_admin.go':['TAHFIDZ_TARGET_UPDATED'],
 'services/academic/main.go':['GRADE_CREATED','SUBJECT_CREATED'],
 'services/academic/admin_extra.go':['REPORT_CREATED'],
 'services/academic/operational_admin.go':['SUBJECT_UPDATED','GRADE_UPDATED','GRADE_PUBLISHED','REPORT_PUBLISHED'],
 'services/donation/main.go':['CAMPAIGN_CREATED','PAYMENT_METHOD_CREATED','PAYMENT_VERIFIED'],
 'services/donation/admin_extra.go':['CAMPAIGN_UPDATE_CREATED'],
 'services/donation/operational_admin.go':['CAMPAIGN_UPDATED','PAYMENT_METHOD_UPDATED'],
 'services/content/admin_extra.go':['CONTENT_CREATED','CONTENT_UPDATED','KAJIAN_UPDATED'],
 'services/content/main.go':['KAJIAN_CREATED'],
 'services/notification/admin_extra.go':['NOTIFICATION_CREATED','NOTIFICATION_SCHEDULED'],
 'services/identity/admin_extra.go':['USER_CREATED','USER_ACCESS_CHANGED'],
}
for path, markers in actions.items():
    for marker in markers:
        need(path,marker,f'audit marker {marker}')
need('services/notification/migrations/003_outbox.sql','CREATE TABLE IF NOT EXISTS outbox_events','notification has transactional outbox migration')

# Browser suite must exercise actual UI contracts, not only route reachability.
e2e='apps/admin-web/e2e/admin-navigation.spec.ts'
for marker in ['Data Santri UI create and update','Tahfidz target UI create then PATCH edit','Donation payment-method UI create and deactivate','Notification compose works through Backoffice BFF','all SUPER_ADMIN Backoffice modules navigate repeatedly']:
    need(e2e,marker,f'browser E2E: {marker}')
need('apps/admin-web/playwright.config.ts','video: "off"','Playwright does not require managed ffmpeg')
need('apps/admin-web/playwright.config.ts','baseURL: process.env.ZABISA_ADMIN_BASE_URL || "http://localhost:3001"','browser E2E uses localhost cookie origin consistently')

failed=[label for ok,label in checks if not ok]
for ok,label in checks:
    print(('PASS ' if ok else 'FAIL ')+label)
if failed:
    print(f'ERROR: {len(failed)} Phase 3.7 contract invariant(s) failed')
    sys.exit(1)
print('=== PHASE 3.7 CONTRACT INVARIANTS: PASS ===')
PY
