#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
KUBECTL_BIN="${KUBECTL:-kubectl}"
NS=zabisa-app
PROBE=zabisa-db-dns-probe
DB_IP=192.168.100.70
DB_PORT=3306
cleanup(){ "$KUBECTL_BIN" -n "$NS" delete pod "$PROBE" --ignore-not-found --wait=false >/dev/null 2>&1 || true; }
trap cleanup EXIT
bash scripts/verify-db-dt-abstraction.sh
bash scripts/verify-cluster-vault-compat.sh
[[ "$("$KUBECTL_BIN" get ns "$NS" -o jsonpath='{.metadata.name}' 2>/dev/null || true)" == "$NS" ]] || { echo '[db-dt] ERROR: zabisa-app namespace missing' >&2; exit 1; }
echo '[db-dt] applying headless db-dt Service + external EndpointSlice...'
"$KUBECTL_BIN" apply -f deploy/kubernetes/base/db-dt.yaml
"$KUBECTL_BIN" -n "$NS" delete pod "$PROBE" --ignore-not-found >/dev/null 2>&1 || true
cat <<'YAML' | "$KUBECTL_BIN" apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: zabisa-db-dns-probe
  namespace: zabisa-app
  labels:
    app.kubernetes.io/name: zabisa-db-dns-probe
    zabisa.network/mysql-access: "true"
spec:
  automountServiceAccountToken: false
  restartPolicy: Never
  securityContext:
    runAsNonRoot: true
    runAsUser: 65532
    runAsGroup: 65532
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: probe
      image: busybox:1.36.1
      command:
        - sh
        - -c
        - |
          set -e
          echo '===== DNS db-dt ====='
          DNS_OUT="$(nslookup db-dt 2>&1 || true)"
          printf '%s\n' "$DNS_OUT"
          printf '%s\n' "$DNS_OUT" | grep -Eq 'Address:[[:space:]]+192\.168\.100\.70$' || {
            echo 'DNS verification failed: db-dt did not return 192.168.100.70' >&2
            exit 20
          }
          echo '===== TCP db-dt:3306 ====='
          nc -vz -w 5 db-dt 3306
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop: ["ALL"]
YAML
phase=''
for _ in $(seq 1 60); do
  phase="$("$KUBECTL_BIN" -n "$NS" get pod "$PROBE" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
  case "$phase" in Succeeded|Failed) break;; esac
  sleep 2
done
"$KUBECTL_BIN" -n "$NS" logs "$PROBE" || true
if [[ "$phase" != Succeeded ]]; then
  echo "[db-dt] ERROR: probe phase=${phase:-unknown}" >&2
  "$KUBECTL_BIN" -n "$NS" describe pod "$PROBE" >&2 || true
  exit 1
fi
resolved="$("$KUBECTL_BIN" -n "$NS" logs "$PROBE" | grep -F "$DB_IP" | head -n1 || true)"
[[ -n "$resolved" ]] || { echo "[db-dt] ERROR: db-dt did not resolve to $DB_IP" >&2; exit 1; }
echo '[db-dt] PASS: db-dt resolves through Kubernetes DNS and TCP/3306 reaches the Docker Compose MySQL host.'
echo '[db-dt] NOTE: no database credentials were used or written.'
