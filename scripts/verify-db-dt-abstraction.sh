#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
FILE=deploy/kubernetes/base/db-dt.yaml
fail(){ echo "[db-dt-verify] ERROR: $*" >&2; exit 1; }
[[ -f "$FILE" ]] || fail "$FILE missing"
grep -q '^kind: Service$' "$FILE" || fail 'Service missing'
grep -q '^  name: db-dt$' "$FILE" || fail 'db-dt name missing'
grep -q '^  clusterIP: None$' "$FILE" || fail 'Service must be headless'
if grep -q '^  selector:' "$FILE"; then fail 'db-dt Service must remain selectorless'; fi
grep -q '^kind: EndpointSlice$' "$FILE" || fail 'EndpointSlice missing'
grep -q 'kubernetes.io/service-name: db-dt' "$FILE" || fail 'EndpointSlice service-name label missing'
grep -q '^addressType: IPv4$' "$FILE" || fail 'IPv4 addressType missing'
grep -q '^      - 192.168.100.70$' "$FILE" || fail 'external DB endpoint IP mismatch'
ports="$(grep -c 'port: 3306' "$FILE" || true)"
[[ "$ports" -ge 2 ]] || fail '3306 must be declared on Service and EndpointSlice'
grep -q '192.168.100.70/32' deploy/kubernetes/base/platform.yaml || fail 'NetworkPolicy does not permit the DB endpoint IP'
grep -q 'zabisa.network/mysql-access: .true.' deploy/kubernetes/base/platform.yaml || fail 'MySQL client pod selector missing'
for svc in identity content student tahfidz academic donation notification; do
  grep -q 'MYSQL_HOST' "deploy/kubernetes/base/${svc}.yaml" || fail "$svc has no MYSQL_HOST"
  grep -q 'value: db-dt' "deploy/kubernetes/base/${svc}.yaml" || fail "$svc MYSQL_HOST is not db-dt"
done
if grep -q 'value: db-dt' deploy/kubernetes/base/api-gateway.yaml; then fail 'api-gateway must not use MySQL'; fi
python3 - <<'PY'
from pathlib import Path
import yaml
p=Path('deploy/kubernetes/base/db-dt.yaml')
docs=list(yaml.safe_load_all(p.read_text()))
assert len(docs)==2
svc,eps=docs
assert svc['kind']=='Service' and svc['spec']['clusterIP']=='None'
assert 'selector' not in svc['spec']
assert svc['spec']['ports'][0]['port']==svc['spec']['ports'][0]['targetPort']==3306
assert eps['kind']=='EndpointSlice'
assert eps['metadata']['labels']['kubernetes.io/service-name']=='db-dt'
assert eps['addressType']=='IPv4'
assert eps['ports'][0]['port']==3306
assert eps['endpoints'][0]['addresses']==['192.168.100.70']
assert eps['endpoints'][0]['conditions']['ready'] is True
PY

# BusyBox nslookup may exit non-zero after search-suffix NXDOMAIN responses even
# when it later prints a valid A record. The runtime probe must validate output
# explicitly instead of letting `set -e` treat that exit status as DNS failure.
APPLY=scripts/apply-db-dt-abstraction.sh
grep -q 'DNS_OUT="$(nslookup db-dt 2>&1 || true)"' "$APPLY" || fail 'probe must tolerate BusyBox nslookup search-suffix exit status'
grep -Fq "grep -Eq 'Address:[[:space:]]+192\\.168\\.100\\.70$'" "$APPLY" || fail 'probe must assert db-dt resolves to 192.168.100.70 from nslookup output'
grep -q 'nc -vz -w 5 db-dt 3306' "$APPLY" || fail 'probe must test TCP using the application hostname db-dt'

echo '[db-dt-verify] OK: headless selectorless Service + manual EndpointSlice point to 192.168.100.70:3306'
echo '[db-dt-verify] OK: existing Calico egress allows only MySQL-labeled pods to 192.168.100.70/32:3306'
echo '[db-dt-verify] OK: 7 stateful services keep MYSQL_HOST=db-dt; api-gateway remains DB-free'
echo '[db-dt-verify] PASS: external MySQL DNS abstraction is internally consistent.'
