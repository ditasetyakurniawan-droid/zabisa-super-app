#!/usr/bin/env bash
set -Eeuo pipefail
set +x
umask 077

sonar_url="${SONAR_URL:-http://192.168.100.59:9000}"
project_key="${SONAR_PROJECT_KEY:-zabisa-platform}"
target="${SONAR_NEW_COVERAGE_TARGET:-75}"
target_gate_name="${SONAR_QUALITY_GATE_NAME:-Zabisa Platform - New Code 75}"
temp_dir="$(mktemp -d /tmp/zabisa-sonar-qg.XXXXXX)"

cleanup() {
  unset sonar_secret SONAR_TOKEN SONAR_SECRET 2>/dev/null || true
  if [[ -d "$temp_dir" && "$temp_dir" == /tmp/zabisa-sonar-qg.* ]]; then
    rm -rf -- "$temp_dir"
  fi
}
trap cleanup EXIT

fail() {
  echo "[sonar-gate] ERROR: $*" >&2
  exit 1
}

[[ "$target" == "75" ]] || fail "reviewed target must remain exactly 75"
command -v curl >/dev/null 2>&1 || fail "curl is required"
command -v python3 >/dev/null 2>&1 || fail "python3 is required"

auth=()
if [[ -n "${SONAR_TOKEN:-}" ]]; then
  auth=(--user "${SONAR_TOKEN}:")
else
  sonar_login="${SONAR_LOGIN:-}"
  if [[ -z "$sonar_login" ]]; then
    printf 'Sonar admin username [admin]: ' >/dev/tty
    IFS= read -r sonar_login </dev/tty
    sonar_login="${sonar_login:-admin}"
  fi
  if [[ -n "${SONAR_SECRET:-}" ]]; then
    sonar_secret="$SONAR_SECRET"
  else
    printf 'Sonar admin password/token (hidden): ' >/dev/tty
    IFS= read -r -s sonar_secret </dev/tty
    printf '\n' >/dev/tty
  fi
  [[ -n "$sonar_secret" ]] || fail "Sonar credential is required"
  auth=(--user "${sonar_login}:${sonar_secret}")
fi

api=(curl --silent --show-error --fail --connect-timeout 5 --max-time 30 "${auth[@]}")

"${api[@]}" "$sonar_url/api/authentication/validate" >"$temp_dir/auth.json"
python3 - "$temp_dir/auth.json" <<'PY'
import json, sys
if json.load(open(sys.argv[1], encoding="utf-8")).get("valid") is not True:
    raise SystemExit("Sonar authentication failed")
PY

"${api[@]}" --get --data-urlencode "project=$project_key" \
  "$sonar_url/api/qualitygates/get_by_project" >"$temp_dir/project-gate.json"

read -r source_gate_id source_gate_name < <(python3 - "$temp_dir/project-gate.json" <<'PY'
import json, sys
gate = json.load(open(sys.argv[1], encoding="utf-8")).get("qualityGate") or {}
gate_id = gate.get("id")
name = gate.get("name")
if not gate_id or not name:
    raise SystemExit("Project Quality Gate was not found")
print(gate_id, name)
PY
)

if [[ "$source_gate_name" != "$target_gate_name" ]]; then
  "${api[@]}" "$sonar_url/api/qualitygates/list" >"$temp_dir/gates.json"
  target_gate_id="$(python3 - "$temp_dir/gates.json" "$target_gate_name" <<'PY'
import json, sys
gates = json.load(open(sys.argv[1], encoding="utf-8")).get("qualitygates") or []
match = next((gate for gate in gates if gate.get("name") == sys.argv[2]), None)
print(match.get("id", "") if match else "")
PY
)"
  if [[ -z "$target_gate_id" ]]; then
    "${api[@]}" -X POST \
      --data-urlencode "sourceName=$source_gate_name" \
      --data-urlencode "name=$target_gate_name" \
      "$sonar_url/api/qualitygates/copy" >/dev/null
  fi
  "${api[@]}" -X POST \
    --data-urlencode "projectKey=$project_key" \
    --data-urlencode "gateName=$target_gate_name" \
    "$sonar_url/api/qualitygates/select" >/dev/null
  "${api[@]}" --get --data-urlencode "project=$project_key" \
    "$sonar_url/api/qualitygates/get_by_project" >"$temp_dir/project-gate.json"
fi

read -r gate_id gate_name < <(python3 - "$temp_dir/project-gate.json" "$target_gate_name" <<'PY'
import json, sys
gate = json.load(open(sys.argv[1], encoding="utf-8")).get("qualityGate") or {}
if gate.get("name") != sys.argv[2] or gate.get("id") is None:
    raise SystemExit("Dedicated project Quality Gate was not selected")
print(gate["id"], gate["name"])
PY
)

"${api[@]}" --get --data-urlencode "id=$gate_id" \
  "$sonar_url/api/qualitygates/show" >"$temp_dir/before.json"

condition_id="$(python3 - "$temp_dir/before.json" "$temp_dir/other-conditions.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
conditions = data.get("conditions") or []
target = next((item for item in conditions if item.get("metric") == "new_coverage"), None)
if not target or target.get("id") is None:
    raise SystemExit("new_coverage condition was not found")
others = sorted((item for item in conditions if item.get("metric") != "new_coverage"), key=lambda item: str(item.get("id")))
json.dump(others, open(sys.argv[2], "w", encoding="utf-8"), sort_keys=True)
print(target["id"])
PY
)"

"${api[@]}" -X POST \
  --data-urlencode "id=$condition_id" \
  --data-urlencode "metric=new_coverage" \
  --data-urlencode "op=LT" \
  --data-urlencode "error=$target" \
  "$sonar_url/api/qualitygates/update_condition" >/dev/null

"${api[@]}" --get --data-urlencode "id=$gate_id" \
  "$sonar_url/api/qualitygates/show" >"$temp_dir/after.json"

python3 - "$temp_dir/after.json" "$temp_dir/other-conditions.json" "$target" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
before_others = json.load(open(sys.argv[2], encoding="utf-8"))
target_value = sys.argv[3]
conditions = data.get("conditions") or []
coverage = next((item for item in conditions if item.get("metric") == "new_coverage"), None)
if not coverage or coverage.get("op") != "LT" or str(coverage.get("error")) not in {target_value, f"{target_value}.0"}:
    raise SystemExit("new_coverage condition did not become 75%")
after_others = sorted((item for item in conditions if item.get("metric") != "new_coverage"), key=lambda item: str(item.get("id")))
if after_others != before_others:
    raise SystemExit("A non-coverage Quality Gate condition changed unexpectedly")
PY

printf '[sonar-gate] PASS: %s / %s new-code coverage threshold is %s%%; all other conditions are unchanged.\n' \
  "$project_key" "$gate_name" "$target"
