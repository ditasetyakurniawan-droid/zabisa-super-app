#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

required=(
  scripts/run-zabisa-dt5-backup-restore.sh
  scripts/run-zabisa-dt5-dt8-rollout.sh
  scripts/bootstrap-zabisa-dt-super-admin.sh
  scripts/open-zabisa-dt-internal-access.sh
  scripts/record-dt58-completion.sh
  tools/password-hash/main.go
  docs/deployment/PHASE-DT5-DT8-CONTROLLED-ROLLOUT.md
)
for path in "${required[@]}"; do [[ -f "$path" ]] || { echo "[dt58-source] ERROR: missing $path"; exit 1; }; done

grep -Fq 'RUN-DT5-BACKUP-RESTORE' scripts/run-zabisa-dt5-backup-restore.sh
grep -Fq -- '--network none' scripts/run-zabisa-dt5-backup-restore.sh
grep -Fq 'aes-256-cbc' scripts/run-zabisa-dt5-backup-restore.sh
grep -Fq -- '--source-data=2' scripts/run-zabisa-dt5-backup-restore.sh
grep -Fq 'RUN-CONTENT-CANARY-' scripts/run-zabisa-dt5-dt8-rollout.sh
grep -Fq 'SYNC-ZABISA-DT-' scripts/run-zabisa-dt5-dt8-rollout.sh
grep -Fq 'ACCEPT-DT8-INTERNAL' scripts/run-zabisa-dt5-dt8-rollout.sh
grep -Fq 'revision": sys.argv[1]' scripts/run-zabisa-dt5-dt8-rollout.sh
grep -Fq 'prune": False' scripts/run-zabisa-dt5-dt8-rollout.sh
grep -Fq "role='SUPER_ADMIN'" scripts/bootstrap-zabisa-dt-super-admin.sh
grep -Fq 'HashPassword' tools/password-hash/main.go

if grep -Eq 'admin@zabisa\.local|ChangeMe123!|Development seed:' apps/admin-web/app/login/LoginForm.tsx; then
  echo '[dt58-source] ERROR: production Backoffice login exposes development credentials'
  exit 1
fi

grep -Fq 'targetRevision: main' deploy/argocd/application.yaml
if grep -Eq 'automated:|selfHeal:|prune: true' deploy/argocd/application.yaml; then
  echo '[dt58-source] ERROR: ArgoCD automatic/destructive sync is forbidden for first DT rollout'
  exit 1
fi

for script in \
  scripts/run-zabisa-dt5-backup-restore.sh \
  scripts/run-zabisa-dt5-dt8-rollout.sh \
  scripts/bootstrap-zabisa-dt-super-admin.sh \
  scripts/open-zabisa-dt-internal-access.sh \
  scripts/record-dt58-completion.sh; do
  bash -n "$script"
done

echo '[dt58-source] PASS: recovery, canary, exact-revision sync, secure admin and internal acceptance controls are present.'
