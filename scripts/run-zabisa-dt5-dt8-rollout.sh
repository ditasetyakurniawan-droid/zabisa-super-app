#!/usr/bin/env bash
set -Eeuo pipefail
set +x
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

readonly NAMESPACE='zabisa-app'
readonly ARGO_NAMESPACE='argocd'
readonly ARGO_APP='zabisa-dt'
readonly SERVICES=(identity content student tahfidz academic donation notification)
readonly DEPLOYMENTS=(identity content student tahfidz academic donation notification api-gateway admin-web)

fail() { printf '[dt5-dt8] ERROR: %s\n' "$*" >&2; exit 1; }
log() { printf '[dt5-dt8] %s\n' "$*"; }
need() { command -v "$1" >/dev/null 2>&1 || fail "$1 is required"; }

mode="${1:---plan}"
case "$mode" in --plan|--run) ;; *) fail 'usage: run-zabisa-dt5-dt8-rollout.sh --plan|--run' ;; esac

gitops_repo="${ZABISA_GITOPS_REPO:-$HOME/project-homelab/zabisa-super-app-gitops}"
[[ -d "$gitops_repo/.git" ]] || fail "GitOps repository is missing: $gitops_repo"
[[ -x "$gitops_repo/scripts/verify-gitops.sh" ]] || fail 'GitOps verifier is missing or not executable'

for command_name in git python3 curl sha256sum mktemp date; do need "$command_name"; done
KUBECTL_BIN="${KUBECTL:-${KUBECTL_BIN:-kubectl}}"
command -v "$KUBECTL_BIN" >/dev/null 2>&1 || fail "kubectl is unavailable: $KUBECTL_BIN"

[[ -z "$(git status --porcelain=v1)" ]] || fail 'application repository worktree is not clean'
[[ -z "$(git -C "$gitops_repo" status --porcelain=v1)" ]] || fail 'GitOps repository worktree is not clean'
[[ "$(git branch --show-current)" == main ]] || fail 'application repository must be on main'
[[ "$(git -C "$gitops_repo" branch --show-current)" == main ]] || fail 'GitOps repository must be on main'

git fetch origin main
git -C "$gitops_repo" fetch origin main
[[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || fail 'application HEAD differs from origin/main'
[[ "$(git -C "$gitops_repo" rev-parse HEAD)" == "$(git -C "$gitops_repo" rev-parse origin/main)" ]] ||
  fail 'GitOps HEAD differs from origin/main'

app_revision="$(git rev-parse HEAD)"
gitops_revision="$(git -C "$gitops_repo" rev-parse HEAD)"
rendered_revision="$(tr -d '\r\n' < "$gitops_repo/apps/zabisa/overlays/dt/SOURCE_REVISION")"
[[ "$rendered_revision" == "$app_revision" ]] ||
  fail "GitOps source revision $rendered_revision does not match application $app_revision"
"$gitops_repo/scripts/verify-gitops.sh"
./scripts/verify-dt3-source.sh
./scripts/preflight-offline.sh

if [[ "$mode" == '--plan' ]]; then
  cat <<EOF
[dt5-dt8] PLAN PASS
Application revision : $app_revision
GitOps revision      : $gitops_revision
Exposure             : internal port-forward only
DT5                  : encrypted seven-schema backup + network-isolated restore
DT6 canary           : content-migrate only; verify then explicit stop gate
DT7                  : exact GitOps revision manual ArgoCD sync
DT8                  : rollout, Vault, migration inventory, API, Backoffice, Android
No cluster or database mutation was performed.
EOF
  exit 0
fi

[[ "${DT58_CONFIRM:-}" == 'RUN-DT5-DT8-INTERNAL' ]] ||
  fail 'set DT58_CONFIRM=RUN-DT5-DT8-INTERNAL'
[[ -r /dev/tty && -w /dev/tty ]] || fail 'interactive terminal is required for rollout approvals'

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
evidence_dir="${ZABISA_DT58_EVIDENCE_DIR:-$HOME/Downloads/zabisa-dt58-evidence-$stamp}"
mkdir -p "$evidence_dir"
chmod 700 "$evidence_dir"
temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/zabisa-dt58.XXXXXX")"
content_job="$temp_dir/content-migrate.yaml"
api_forward_log="$evidence_dir/api-port-forward.log"
admin_forward_log="$evidence_dir/admin-port-forward.log"
api_forward_pid=''
admin_forward_pid=''
android_serial=''
content_job_created=false

cleanup() {
  rc=$?
  set +e
  [[ -n "$api_forward_pid" ]] && kill "$api_forward_pid" >/dev/null 2>&1
  [[ -n "$admin_forward_pid" ]] && kill "$admin_forward_pid" >/dev/null 2>&1
  [[ -n "$android_serial" ]] && adb -s "$android_serial" reverse --remove tcp:8088 >/dev/null 2>&1
  if [[ "$content_job_created" == true ]]; then
    "$KUBECTL_BIN" -n "$NAMESPACE" delete job content-migrate --ignore-not-found --wait=false >/dev/null 2>&1
  fi
  rm -rf -- "$temp_dir"
  exit "$rc"
}
trap cleanup EXIT INT TERM

printf 'Nama reviewer DT5 recovery evidence: ' >/dev/tty
IFS= read -r dt5_reviewer </dev/tty
reviewer_pattern='^[[:alnum:]][[:alnum:] ._-]{2,79}$'
[[ "$dt5_reviewer" =~ $reviewer_pattern ]] || fail 'reviewer name must be 3..80 safe characters'

log 'DT5: backup and isolated restore recovery proof'
DT5_CONFIRM=RUN-DT5-BACKUP-RESTORE ZABISA_DT5_REVIEWER="$dt5_reviewer" \
  ./scripts/run-zabisa-dt5-backup-restore.sh --run |
  tee "$evidence_dir/dt5-backup-restore.log"

printf '\nReview DT5 log, archive SHA-256/binlog position, dan pastikan passphrase sudah disalin ke secret store terpisah.\n' >/dev/tty
printf 'Ketik ACCEPT-DT5-RECOVERY-%s: ' "${app_revision:0:7}" >/dev/tty
IFS= read -r dt5_confirmation </dev/tty
[[ "$dt5_confirmation" == "ACCEPT-DT5-RECOVERY-${app_revision:0:7}" ]] ||
  fail 'DT5 recovery proof was not accepted; no migration was requested'
printf 'reviewer=%s\naccepted_revision=%s\naccepted_at=%s\n' \
  "$dt5_reviewer" "$app_revision" "$(date -u +%FT%TZ)" > "$evidence_dir/dt5-review.env"
chmod 600 "$evidence_dir/dt5-review.env"

log 'DT6 preflight: Kubernetes identity, CA and MySQL authentication'
"$KUBECTL_BIN" version -o json > "$evidence_dir/kubernetes-version.json"
"$KUBECTL_BIN" -n "$NAMESPACE" get secret vault-ca mysql-ca -o name > "$evidence_dir/ca-secrets.txt"
"$KUBECTL_BIN" -n "$NAMESPACE" get service db-dt -o yaml > "$evidence_dir/db-dt-service.yaml"
./scripts/run-zabisa-mysql-credential-canary.sh |
  tee "$evidence_dir/mysql-credential-canary.log"

capture_inventory() {
  local output="$1"
  DT3_CONFIRM=RUN-READ-ONLY-DT3-INVENTORY \
    "$ROOT/scripts/run-zabisa-mysql-schema-inventory.sh" --run | tee "$output"
}

assert_inventory_row() {
  local file="$1" service="$2" rows="$3" checksum="$4"
  grep -Eq "service=$service database=${service}_db .*migration_rows=$rows checksum_column=$checksum" "$file" ||
    fail "unexpected $service migration state in $file"
}

pre_inventory="$evidence_dir/inventory-before-canary.log"
capture_inventory "$pre_inventory"

content_rows="$(find services/content/migrations -maxdepth 1 -type f -name '*.sql' | wc -l | tr -d ' ')"
empty_state=true
content_only_state=true
full_state=true
for service in "${SERVICES[@]}"; do
  expected_rows="$(find "services/$service/migrations" -maxdepth 1 -type f -name '*.sql' | wc -l | tr -d ' ')"
  grep -Eq "service=$service database=${service}_db .*migration_rows=0 checksum_column=0" "$pre_inventory" || empty_state=false
  if [[ "$service" == content ]]; then
    grep -Eq "service=content database=content_db .*migration_rows=$content_rows checksum_column=1" "$pre_inventory" || content_only_state=false
  else
    grep -Eq "service=$service database=${service}_db .*migration_rows=0 checksum_column=0" "$pre_inventory" || content_only_state=false
  fi
  grep -Eq "service=$service database=${service}_db .*migration_rows=$expected_rows checksum_column=1" "$pre_inventory" || full_state=false
done
if [[ "$empty_state" != true && "$content_only_state" != true && "$full_state" != true ]]; then
  fail 'database state is neither empty, content-canary-only, nor fully migrated; inspect inventory evidence'
fi

python3 - "$gitops_repo/apps/zabisa/overlays/dt/manifests/migrations.yaml" "$content_job" <<'PY'
from pathlib import Path
import re
import sys

source = Path(sys.argv[1]).read_text(encoding="utf-8")
matches = [part.strip() for part in re.split(r"\n---\s*\n", source) if re.search(r"(?m)^  name: content-migrate$", part)]
if len(matches) != 1:
    raise SystemExit(f"expected one content-migrate document, found {len(matches)}")
Path(sys.argv[2]).write_text(matches[0] + "\n", encoding="utf-8")
PY
grep -Fq "image: harbor-dt.co.id/devops-apps/zabisa/content:$app_revision" "$content_job" ||
  fail 'content canary does not use the exact application revision'
grep -Fq 'backoffLimit: 0' "$content_job" || fail 'content canary must have zero retry'

if [[ "$empty_state" == true ]]; then
  printf '\nDT6 content canary akan mengubah content_db pada recovery point yang baru diuji.\n' >/dev/tty
  printf 'Ketik RUN-CONTENT-CANARY-%s: ' "${app_revision:0:7}" >/dev/tty
  IFS= read -r canary_confirmation </dev/tty
  [[ "$canary_confirmation" == "RUN-CONTENT-CANARY-${app_revision:0:7}" ]] || fail 'content canary approval did not match'

  log 'DT6: creating the exact content migration canary'
  "$KUBECTL_BIN" -n "$NAMESPACE" get job content-migrate >/dev/null 2>&1 &&
    fail 'content-migrate job already exists and must be inspected first'
  "$KUBECTL_BIN" create -f "$content_job" > "$evidence_dir/content-canary-create.txt"
  content_job_created=true
  if ! "$KUBECTL_BIN" -n "$NAMESPACE" wait --for=condition=complete job/content-migrate --timeout=360s; then
    "$KUBECTL_BIN" -n "$NAMESPACE" logs job/content-migrate --all-containers --tail=300 > "$evidence_dir/content-canary-failure.log" 2>&1 || true
    "$KUBECTL_BIN" -n "$NAMESPACE" get job content-migrate -o yaml > "$evidence_dir/content-canary-failure.yaml" 2>&1 || true
    fail 'content migration canary failed; full sync was not requested'
  fi
  "$KUBECTL_BIN" -n "$NAMESPACE" logs job/content-migrate --all-containers --tail=300 > "$evidence_dir/content-canary.log"
  "$KUBECTL_BIN" -n "$NAMESPACE" get job content-migrate -o yaml > "$evidence_dir/content-canary.yaml"
  "$KUBECTL_BIN" -n "$NAMESPACE" delete job content-migrate --wait=true >/dev/null
  content_job_created=false

  post_canary_inventory="$evidence_dir/inventory-after-content-canary.log"
  capture_inventory "$post_canary_inventory"
  assert_inventory_row "$post_canary_inventory" content "$content_rows" 1
  for service in identity student tahfidz academic donation notification; do
    assert_inventory_row "$post_canary_inventory" "$service" 0 0
  done
  log 'DT6 canary PASS: content schema/checksums verified; remaining schemas unchanged'
elif [[ "$content_only_state" == true ]]; then
  log 'DT6 resume: the exact content canary is already verified; it will not be rerun separately'
else
  log 'DT6 resume: all migration checksums already match; ArgoCD will perform an idempotent reconciliation'
fi

printf '\nDT7 akan sync revision GitOps %s dan menjalankan sisa PreSync migrations.\n' "$gitops_revision" >/dev/tty
printf 'Ketik SYNC-ZABISA-DT-%s: ' "${gitops_revision:0:7}" >/dev/tty
IFS= read -r sync_confirmation </dev/tty
[[ "$sync_confirmation" == "SYNC-ZABISA-DT-${gitops_revision:0:7}" ]] ||
  fail 'ArgoCD sync approval did not match'

log 'DT7: applying manual Application and requesting exact-revision sync'
"$KUBECTL_BIN" -n "$ARGO_NAMESPACE" get crd applications.argoproj.io >/dev/null
"$KUBECTL_BIN" apply -f deploy/argocd/application.yaml > "$evidence_dir/argocd-application-apply.txt"
sync_patch="$(python3 - "$gitops_revision" <<'PY'
import json, sys
print(json.dumps({"operation": {"sync": {"revision": sys.argv[1], "prune": False, "syncOptions": ["CreateNamespace=false", "PrunePropagationPolicy=foreground", "PruneLast=true"]}}}))
PY
)"
"$KUBECTL_BIN" -n "$ARGO_NAMESPACE" patch application "$ARGO_APP" --type merge -p "$sync_patch" > "$evidence_dir/argocd-sync-request.txt"

argo_succeeded=false
for attempt in $(seq 1 120); do
  phase="$("$KUBECTL_BIN" -n "$ARGO_NAMESPACE" get application "$ARGO_APP" -o jsonpath='{.status.operationState.phase}' 2>/dev/null || true)"
  sync_status="$("$KUBECTL_BIN" -n "$ARGO_NAMESPACE" get application "$ARGO_APP" -o jsonpath='{.status.sync.status}' 2>/dev/null || true)"
  health="$("$KUBECTL_BIN" -n "$ARGO_NAMESPACE" get application "$ARGO_APP" -o jsonpath='{.status.health.status}' 2>/dev/null || true)"
  if [[ "$phase" == Succeeded && "$sync_status" == Synced && "$health" == Healthy ]]; then
    argo_succeeded=true
    break
  fi
  if [[ "$phase" == Failed || "$phase" == Error ]]; then
    "$KUBECTL_BIN" -n "$ARGO_NAMESPACE" get application "$ARGO_APP" -o yaml > "$evidence_dir/argocd-failure.yaml"
    fail "ArgoCD operation entered $phase"
  fi
  if (( attempt == 1 || attempt % 10 == 0 )); then
    log "ArgoCD attempt $attempt: operation=${phase:-pending} sync=${sync_status:-pending} health=${health:-pending}"
  fi
  sleep 5
done
[[ "$argo_succeeded" == true ]] || {
  "$KUBECTL_BIN" -n "$ARGO_NAMESPACE" get application "$ARGO_APP" -o yaml > "$evidence_dir/argocd-timeout.yaml"
  fail 'ArgoCD did not reach Succeeded/Synced/Healthy within 10 minutes'
}
"$KUBECTL_BIN" -n "$ARGO_NAMESPACE" get application "$ARGO_APP" -o yaml > "$evidence_dir/argocd-application-final.yaml"
synced_revision="$("$KUBECTL_BIN" -n "$ARGO_NAMESPACE" get application "$ARGO_APP" -o jsonpath='{.status.sync.revision}')"
[[ "$synced_revision" == "$gitops_revision" ]] || fail "ArgoCD synced unexpected revision: $synced_revision"

full_inventory="$evidence_dir/inventory-after-argocd.log"
capture_inventory "$full_inventory"
for service in "${SERVICES[@]}"; do
  expected_rows="$(find "services/$service/migrations" -maxdepth 1 -type f -name '*.sql' | wc -l | tr -d ' ')"
  assert_inventory_row "$full_inventory" "$service" "$expected_rows" 1
done

admin_email_file="${ZABISA_OPERATOR_CREDENTIAL_DIR:-$HOME/.config/zabisa}/dt-admin-email"
admin_password_file="${ZABISA_OPERATOR_CREDENTIAL_DIR:-$HOME/.config/zabisa}/dt-admin-password"
if [[ ! -e "$admin_email_file" && ! -e "$admin_password_file" ]]; then
  log 'DT8: creating the initial operator-selected SUPER_ADMIN'
  DT8_ADMIN_CONFIRM=CREATE-INITIAL-DT-SUPER-ADMIN ./scripts/bootstrap-zabisa-dt-super-admin.sh --run |
    tee "$evidence_dir/admin-bootstrap.log"
elif [[ -r "$admin_email_file" && -r "$admin_password_file" ]]; then
  log 'DT8 resume: protected operator admin credentials already exist; database identity will be verified by login'
else
  fail 'incomplete DT admin credential files; inspect before retry'
fi

log 'DT8: rollout and Vault acceptance'
for deployment in "${DEPLOYMENTS[@]}"; do
  "$KUBECTL_BIN" -n "$NAMESPACE" rollout status "deployment/$deployment" --timeout=300s
done
"$KUBECTL_BIN" -n "$NAMESPACE" get deployments,pods,services -o wide > "$evidence_dir/workloads.txt"
"$KUBECTL_BIN" -n "$NAMESPACE" get pods -o json > "$evidence_dir/pods.json"
python3 - "$evidence_dir/pods.json" <<'PY'
import json, sys

pods = json.load(open(sys.argv[1], encoding="utf-8"))["items"]
expected = {"identity", "content", "student", "tahfidz", "academic", "donation", "notification", "api-gateway", "admin-web"}
seen = set()
for pod in pods:
    labels = pod["metadata"].get("labels", {})
    app = labels.get("app")
    if app not in expected:
        continue
    seen.add(app)
    ready = any(c.get("type") == "Ready" and c.get("status") == "True" for c in pod.get("status", {}).get("conditions", []))
    if not ready:
        raise SystemExit(f"pod for {app} is not Ready")
    annotations = pod["metadata"].get("annotations", {})
    injected = annotations.get("vault.hashicorp.com/agent-inject-status") == "injected"
    if app == "admin-web" and injected:
        raise SystemExit("admin-web must remain Vault-free")
    if app != "admin-web" and not injected:
        raise SystemExit(f"Vault injection is not proven for {app}")
if seen != expected:
    raise SystemExit(f"missing application pods: {sorted(expected - seen)}")
print("PASS: nine Ready workloads and reviewed Vault boundary verified")
PY

for port in 18088 13001; do
  python3 - "$port" <<'PY'
import socket, sys
s = socket.socket()
try:
    s.bind(("127.0.0.1", int(sys.argv[1])))
finally:
    s.close()
PY
done
"$KUBECTL_BIN" -n "$NAMESPACE" port-forward service/api-gateway 18088:8080 > "$api_forward_log" 2>&1 &
api_forward_pid=$!
"$KUBECTL_BIN" -n "$NAMESPACE" port-forward service/admin-web 13001:3000 > "$admin_forward_log" 2>&1 &
admin_forward_pid=$!

for attempt in $(seq 1 60); do
  curl -fsS http://127.0.0.1:18088/health/ready >/dev/null 2>&1 &&
    curl -fsS http://127.0.0.1:13001/login >/dev/null 2>&1 && break
  (( attempt < 60 )) || fail 'internal API/Backoffice port-forward did not become ready'
  sleep 1
done
curl -fsS http://127.0.0.1:18088/health/live > "$evidence_dir/api-live.json"
curl -fsS http://127.0.0.1:18088/health/ready > "$evidence_dir/api-ready.json"
curl -fsS http://127.0.0.1:13001/login > "$evidence_dir/backoffice-login.html"
if grep -Eq 'admin@zabisa\.local|ChangeMe123!|Development seed' "$evidence_dir/backoffice-login.html"; then
  fail 'deployed Backoffice still exposes development credentials'
fi

login_payload="$temp_dir/login.json"
login_response="$temp_dir/login-response.json"
python3 - "$admin_email_file" "$admin_password_file" "$login_payload" <<'PY'
import json, pathlib, sys
email = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8").strip()
password = pathlib.Path(sys.argv[2]).read_text(encoding="utf-8").rstrip("\r\n")
pathlib.Path(sys.argv[3]).write_text(json.dumps({"email": email, "password": password, "device_id": "dt8-acceptance"}), encoding="utf-8")
PY
chmod 600 "$login_payload"
curl -fsS http://127.0.0.1:18088/api/v1/auth/login \
  -H 'Content-Type: application/json' --data-binary @"$login_payload" > "$login_response"
python3 - "$login_response" <<'PY'
import json, sys
body = json.load(open(sys.argv[1], encoding="utf-8"))
data = body.get("data") or {}
assert data.get("access_token"), "missing access token"
assert (data.get("user") or {}).get("role") == "SUPER_ADMIN", "unexpected role"
print("PASS: DT SUPER_ADMIN authenticated through API Gateway")
PY
rm -f "$login_payload" "$login_response"

need adb
mapfile -t devices < <(adb devices | awk 'NR>1 && $2=="device" {print $1}')
(( ${#devices[@]} == 1 )) || fail "exactly one authorized Android device is required; found ${#devices[@]}"
android_serial="${devices[0]}"
adb -s "$android_serial" reverse tcp:8088 tcp:18088 >/dev/null
adb -s "$android_serial" shell pm path id.or.subulussalam.zabisa >/dev/null ||
  fail 'Zabisa Android debug app is not installed'
adb -s "$android_serial" shell monkey -p id.or.subulussalam.zabisa -c android.intent.category.LAUNCHER 1 >/dev/null

if command -v xdg-open >/dev/null 2>&1; then
  xdg-open http://127.0.0.1:13001/login >/dev/null 2>&1 || true
fi
printf '\nDT8 manual acceptance:\n' >/dev/tty
printf '1. Backoffice: http://127.0.0.1:13001/login\n' >/dev/tty
printf '2. Login dengan credential lokal di ~/.config/zabisa/dt-admin-*\n' >/dev/tty
printf '3. Di HP, buka Beranda/Kajian/Donasi/Akun dan pastikan data/API normal.\n' >/dev/tty
printf 'Ketik ACCEPT-DT8-INTERNAL hanya setelah kedua UI terbukti: ' >/dev/tty
IFS= read -r acceptance_confirmation </dev/tty
[[ "$acceptance_confirmation" == 'ACCEPT-DT8-INTERNAL' ]] || fail 'manual DT8 acceptance was not confirmed'

finished_at="$(date -u +%FT%TZ)"
{
  printf 'status=PASS\n'
  printf 'finished_at=%s\n' "$finished_at"
  printf 'application_revision=%s\n' "$app_revision"
  printf 'gitops_revision=%s\n' "$gitops_revision"
  printf 'argocd_revision=%s\n' "$synced_revision"
  printf 'namespace=%s\n' "$NAMESPACE"
  printf 'exposure=internal-port-forward-only\n'
  printf 'migration_rows_verified=true\n'
  printf 'android_device_acceptance=confirmed\n'
  printf 'backoffice_acceptance=confirmed\n'
} > "$evidence_dir/RESULT.env"
chmod 600 "$evidence_dir/RESULT.env"

log 'PASS: DT5 backup/restore, DT6 migrations, DT7 ArgoCD sync and DT8 internal acceptance complete'
log "application revision: $app_revision"
log "GitOps/ArgoCD revision: $gitops_revision"
log "evidence: $evidence_dir"
log 'public DNS/TLS/Ingress remains intentionally out of scope'
