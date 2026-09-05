#!/usr/bin/env bash

set -Eeuo pipefail
set +x
umask 077

mode="${1:---plan}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target_job="zabisa-super-app-v1"
branch_job="main"
jenkins_ssh_target="${JENKINS_SSH_TARGET:-ubuntu@192.168.100.57}"
jenkins_local_port="${JENKINS_LOCAL_PORT:-18080}"
jenkins_url="http://127.0.0.1:${jenkins_local_port}"
harbor_credentials_id="${HARBOR_CREDENTIALS_ID:-harbor-cred}"
gitops_credentials_id="${GITOPS_CREDENTIALS_ID:-github-credentials-id}"

temp_dir=""
tunnel_pid=""
job_enabled=false
readiness_build=""
delivery_build=""
curl_auth=()
post_headers=()

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/run-zabisa-jenkins-delivery.sh --plan
  DT44_CONFIRM=RUN-JENKINS-BUILD-PUSH \
    ./scripts/run-zabisa-jenkins-delivery.sh --run
  DT44_CONFIRM=RUN-JENKINS-BUILD-PUSH \
  DT43_READINESS_BUILD=<successful-build-number> \
    ./scripts/run-zabisa-jenkins-delivery.sh --resume-after-readiness

The controlled run enables the existing disabled Multibranch job, performs a
default-off readiness build, then runs build/scan/push/render with explicit
parameters. Resume mode verifies and reuses an already successful default-off
readiness build, then starts only build/scan/push/render. Both modes disable the
parent job again before returning.
USAGE
}

case "$mode" in
  --plan|--run|--resume-after-readiness) ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 64 ;;
esac

jenkins_post() {
  local path="$1"
  shift

  curl --silent --show-error \
    --output "$temp_dir/post-response.txt" \
    --write-out '%{http_code}' \
    --netrc-file "$temp_dir/jenkins.netrc" \
    --connect-timeout 5 --max-time 30 \
    "${post_headers[@]}" \
    "$@" \
    -X POST "$jenkins_url$path"
}

disable_parent() {
  set +e

  if [[ "$job_enabled" == true && -s "$temp_dir/jenkins.netrc" ]]; then
    status="$(jenkins_post "/job/$target_job/disable")"
    if [[ "$status" == "200" || "$status" == "302" ]]; then
      echo "[jenkins-delivery] parent job returned to DISABLED."
      job_enabled=false
    else
      echo "[jenkins-delivery] WARNING: disable returned HTTP $status" >&2
    fi
  fi
}

cleanup() {
  set +e
  disable_parent

  if [[ -n "${tunnel_pid:-}" ]] && kill -0 "$tunnel_pid" 2>/dev/null; then
    kill "$tunnel_pid" 2>/dev/null || true
    wait "$tunnel_pid" 2>/dev/null || true
  fi

  if [[ -n "${temp_dir:-}" && -d "$temp_dir" &&
        "$temp_dir" == /tmp/zabisa-jenkins-delivery.* ]]; then
    rm -rf -- "$temp_dir"
  fi

  unset jenkins_api_token 2>/dev/null || true
}

failure_report() {
  rc=$?
  set +e
  echo
  echo "============================================"
  echo "JENKINS DT4.3/DT4.4 DELIVERY GAGAL"
  echo "Exit code : $rc"
  echo "Command   : $BASH_COMMAND"
  echo "Readiness : ${readiness_build:-not-started}"
  echo "Delivery  : ${delivery_build:-not-started}"
  echo "Parent job will be returned to DISABLED."
  echo "Kubernetes, MySQL migration and ArgoCD sync were not requested."
  echo "============================================"
  exit "$rc"
}

wait_build() {
  local build_number="$1"
  local label="$2"
  local build_json=""
  local building=""
  local result=""

  for attempt in $(seq 1 120); do
    if build_json="$(
      curl "${curl_auth[@]}" \
        "$jenkins_url/job/$target_job/job/$branch_job/$build_number/api/json?tree=building,result" \
        2>/dev/null
    )"; then
      read -r building result < <(
        python3 -c '
import json
import sys

build = json.load(sys.stdin)
print(str(build.get("building", True)).lower(), build.get("result") or "pending")
' <<<"$build_json"
      )

      printf '[jenkins-delivery] %s #%s attempt %s: building=%s result=%s\n' \
        "$label" "$build_number" "$attempt" "$building" "$result"

      if [[ "$building" == "false" ]]; then
        [[ "$result" == "SUCCESS" ]] || {
          echo "ERROR: $label build #$build_number result=$result" >&2
          echo "===== SANITIZED $label BUILD LOG TAIL =====" >&2
          curl "${curl_auth[@]}" \
            "$jenkins_url/job/$target_job/job/$branch_job/$build_number/consoleText" \
            2>/dev/null |
            sed -E \
              -e 's/([Tt]oken|[Pp]assword|[Ss]ecret)([=:][^[:space:]]*)?/\1=[REDACTED]/g' \
              -e 's/(Authorization:)[[:space:]]*[^[:space:]]+/\1 [REDACTED]/Ig' |
            tail -n 240 >&2 || true
          return 1
        }
        return 0
      fi
    else
      echo "[jenkins-delivery] $label #$build_number belum tersedia; attempt $attempt"
    fi

    sleep 10
  done

  echo "ERROR: timeout waiting for $label build #$build_number" >&2
  return 1
}

trap cleanup EXIT
trap failure_report ERR

cd "$root"

commit="$(git rev-parse HEAD)"

echo "===== DT4.3/DT4.4 CONTROL PLAN ====="
echo "Source commit     : $commit"
echo "Jenkins           : $jenkins_ssh_target"
echo "Parent job        : $target_job"
echo "Readiness build   : quality + private Sonar + Dockerized Trivy"
echo "Delivery build    : 9 images + scan + SBOM + Harbor push + GitOps render"
echo "Harbor credential : $harbor_credentials_id"
echo "GitOps credential : $gitops_credentials_id"
echo "Final job state   : DISABLED"
echo "Migration         : NOT RUN"
echo "ArgoCD sync       : NOT RUN"
echo "Credential values : NOT DISPLAYED"
if [[ "$mode" == "--resume-after-readiness" ]]; then
  echo "Resume proof       : Jenkins readiness build ${DT43_READINESS_BUILD:-NOT-SET}"
fi

if [[ "$mode" == "--plan" ]]; then
  echo "PLAN PASS: no Jenkins, Docker, Harbor, Kubernetes or database mutation performed."
  exit 0
fi

[[ "${DT44_CONFIRM:-}" == "RUN-JENKINS-BUILD-PUSH" ]] || {
  echo "ERROR: set DT44_CONFIRM=RUN-JENKINS-BUILD-PUSH for --run." >&2
  exit 10
}

[[ "$commit" =~ ^[0-9a-f]{40}$ ]] || exit 11
[[ "$(git branch --show-current)" == "main" ]] || {
  echo "ERROR: branch aktif bukan main." >&2
  exit 12
}
[[ -z "$(git status --porcelain=v1)" ]] || {
  echo "ERROR: worktree tidak bersih." >&2
  exit 13
}

git fetch origin main
[[ "$(git rev-parse origin/main)" == "$commit" ]] || {
  echo "ERROR: local HEAD tidak sama dengan origin/main." >&2
  exit 14
}

./scripts/verify-dt43-delivery-controls.sh
./scripts/preflight-offline.sh

temp_dir="$(mktemp -d /tmp/zabisa-jenkins-delivery.XXXXXX)"

ssh -o BatchMode=yes \
  -o ConnectTimeout=30 \
  -o ConnectionAttempts=3 \
  -o ExitOnForwardFailure=yes \
  -N \
  -L "127.0.0.1:${jenkins_local_port}:127.0.0.1:8080" \
  "$jenkins_ssh_target" &
tunnel_pid=$!

for attempt in $(seq 1 30); do
  if curl -fsS --connect-timeout 2 --max-time 3 \
       "$jenkins_url/login" >/dev/null 2>&1; then
    break
  fi
  kill -0 "$tunnel_pid" 2>/dev/null || exit 20
  [[ "$attempt" -lt 30 ]] || exit 21
  sleep 1
done

read -r -p 'Jenkins username: ' jenkins_username
read -r -s -p 'Jenkins API token (hidden): ' jenkins_api_token
echo

[[ -n "$jenkins_username" && "$jenkins_username" != *[[:space:]]* ]] || exit 22
[[ -n "$jenkins_api_token" && "$jenkins_api_token" != *[[:space:]]* ]] || exit 23

printf 'machine 127.0.0.1\nlogin %s\npassword %s\n' \
  "$jenkins_username" "$jenkins_api_token" >"$temp_dir/jenkins.netrc"
chmod 600 "$temp_dir/jenkins.netrc"
unset jenkins_api_token

curl_auth=(
  --globoff
  --silent --show-error --fail
  --netrc-file "$temp_dir/jenkins.netrc"
  --connect-timeout 5 --max-time 30
)

whoami="$(curl "${curl_auth[@]}" "$jenkins_url/whoAmI/api/json")"
python3 -c '
import json
import sys

data = json.load(sys.stdin)
assert data.get("authenticated") is True
print("Authenticated as:", data.get("name", "unknown"))
' <<<"$whoami"

crumb_header="$(
  curl "${curl_auth[@]}" \
    "$jenkins_url/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,%22:%22,//crumb)" \
    2>/dev/null || true
)"

post_headers=()
if [[ -n "$crumb_header" && "$crumb_header" == *:* ]]; then
  post_headers+=(-H "$crumb_header")
fi

parent_xml="$temp_dir/parent.xml"
curl "${curl_auth[@]}" "$jenkins_url/job/$target_job/config.xml" >"$parent_xml"
if ! grep -Eq '<disabled>[[:space:]]*true[[:space:]]*</disabled>' "$parent_xml"; then
  echo '[jenkins-delivery] recovering parent job left enabled by an interrupted operator terminal.'
  job_enabled=true
  disable_parent
  curl "${curl_auth[@]}" "$jenkins_url/job/$target_job/config.xml" >"$parent_xml"
fi
grep -Eq '<disabled>[[:space:]]*true[[:space:]]*</disabled>' "$parent_xml" || {
  echo "ERROR: parent job could not be returned to the required disabled checkpoint." >&2
  exit 24
}

before_build=0
branch_exists=false
if branch_json="$(
  curl "${curl_auth[@]}" \
    "$jenkins_url/job/$target_job/job/$branch_job/api/json?tree=lastBuild[number]" \
    2>/dev/null
)"; then
  branch_exists=true
  before_build="$(
    python3 -c '
import json
import sys

data = json.load(sys.stdin)
print((data.get("lastBuild") or {}).get("number", 0))
' <<<"$branch_json"
  )"
fi

echo
echo "===== ENABLE AND INDEX ====="

status="$(jenkins_post "/job/$target_job/enable")"
[[ "$status" == "200" || "$status" == "302" ]] || {
  echo "ERROR: enable returned HTTP $status" >&2
  exit 30
}
job_enabled=true

branch_ready=false
if [[ "$branch_exists" == true ]]; then
  branch_ready=true
  echo "[jenkins-delivery] existing main branch job reused; indexing not repeated."
else
  status="$(jenkins_post "/job/$target_job/build?delay=0sec")"
  [[ "$status" == "200" || "$status" == "201" || "$status" == "302" ]] || {
    echo "ERROR: multibranch indexing returned HTTP $status" >&2
    exit 31
  }

  for attempt in $(seq 1 60); do
    if curl "${curl_auth[@]}" \
      "$jenkins_url/job/$target_job/job/$branch_job/api/json?tree=nextBuildNumber,lastBuild[number]" \
      >"$temp_dir/branch.json" 2>/dev/null; then
      branch_ready=true
      break
    fi
    echo "[jenkins-delivery] waiting for main branch job: attempt $attempt"
    sleep 5
  done
fi
[[ "$branch_ready" == true ]] || {
  echo "ERROR: main branch job was not discovered." >&2
  exit 32
}

echo
echo "===== DEFAULT-OFF READINESS BUILD ====="

if [[ "$mode" == "--resume-after-readiness" ]]; then
  readiness_build="${DT43_READINESS_BUILD:-}"
  [[ "$readiness_build" =~ ^[1-9][0-9]*$ ]] || {
    echo 'ERROR: resume mode requires numeric DT43_READINESS_BUILD.' >&2
    exit 34
  }
  echo "[jenkins-delivery] verifying existing readiness build #$readiness_build."
else
  for attempt in $(seq 1 6); do
    branch_json="$(
      curl "${curl_auth[@]}" \
        "$jenkins_url/job/$target_job/job/$branch_job/api/json?tree=lastBuild[number]"
    )"
    readiness_build="$(
      python3 -c '
import json
import sys

data = json.load(sys.stdin)
print((data.get("lastBuild") or {}).get("number", 0))
' <<<"$branch_json"
    )"

    if (( readiness_build > before_build )); then
      break
    fi

    if [[ "$attempt" == "3" ]]; then
      status="$(
        jenkins_post "/job/$target_job/job/$branch_job/buildWithParameters" \
          --data-urlencode 'BUILD_IMAGES=false' \
          --data-urlencode 'PUSH_IMAGES=false' \
          --data-urlencode 'RENDER_GITOPS=false' \
          --data-urlencode "HARBOR_CREDENTIALS_ID=$harbor_credentials_id" \
          --data-urlencode "GITOPS_CREDENTIALS_ID=$gitops_credentials_id"
      )"
      [[ "$status" == "200" || "$status" == "201" || "$status" == "302" ]] || {
        echo "ERROR: readiness trigger returned HTTP $status" >&2
        exit 33
      }
      echo "[jenkins-delivery] explicit readiness build requested."
    fi

    sleep 10
  done

  (( readiness_build > before_build )) || {
    echo "ERROR: readiness build was not created." >&2
    exit 34
  }
fi

wait_build "$readiness_build" readiness

readiness_log="$temp_dir/readiness.log"
curl "${curl_auth[@]}" \
  "$jenkins_url/job/$target_job/job/$branch_job/$readiness_build/consoleText" \
  >"$readiness_log"

grep -Fq 'Delivery controls: BUILD_IMAGES=false, PUSH_IMAGES=false, RENDER_GITOPS=false' \
  "$readiness_log" || {
    echo "ERROR: readiness build did not use default-off controls." >&2
    exit 35
  }
grep -Fq 'PASS: digest-pinned Dockerized Trivy and vulnerability DB are ready.' \
  "$readiness_log" || {
    echo "ERROR: Dockerized Trivy readiness proof missing." >&2
    exit 36
  }
if grep -Fq '[images] PUSH' "$readiness_log"; then
  echo "ERROR: readiness build unexpectedly pushed an image." >&2
  exit 37
fi

if [[ "$mode" == "--resume-after-readiness" ]]; then
  echo "PASS: readiness build #$readiness_build was verified and reused without rerun."
else
  echo "PASS: readiness build #$readiness_build completed without image publication."
fi

echo
echo "===== CONTROLLED BUILD, SCAN, PUSH AND RENDER ====="

branch_json="$(
  curl "${curl_auth[@]}" \
    "$jenkins_url/job/$target_job/job/$branch_job/api/json?tree=nextBuildNumber"
)"
delivery_build="$(
  python3 -c '
import json
import sys
print(json.load(sys.stdin)["nextBuildNumber"])
' <<<"$branch_json"
)"

status="$(
  jenkins_post "/job/$target_job/job/$branch_job/buildWithParameters" \
    --data-urlencode 'BUILD_IMAGES=true' \
    --data-urlencode 'PUSH_IMAGES=true' \
    --data-urlencode 'RENDER_GITOPS=true' \
    --data-urlencode "HARBOR_CREDENTIALS_ID=$harbor_credentials_id" \
    --data-urlencode "GITOPS_CREDENTIALS_ID=$gitops_credentials_id"
)"
[[ "$status" == "200" || "$status" == "201" || "$status" == "302" ]] || {
  echo "ERROR: delivery trigger returned HTTP $status" >&2
  exit 40
}

wait_build "$delivery_build" delivery

delivery_log="$temp_dir/delivery.log"
curl "${curl_auth[@]}" \
  "$jenkins_url/job/$target_job/job/$branch_job/$delivery_build/consoleText" \
  >"$delivery_log"

for marker in \
  'Delivery controls: BUILD_IMAGES=true, PUSH_IMAGES=true, RENDER_GITOPS=true' \
  '[images] PASS: mode --build-scan completed for 9 immutable images.' \
  '[images] PASS: mode --push-only completed for 9 immutable images.' \
  '[gitops] PASS: rendered 16 immutable image references across 9 image targets' \
  "[gitops] PASS: published source=$commit"; do
  grep -Fq "$marker" "$delivery_log" || {
    echo "ERROR: delivery evidence marker missing: $marker" >&2
    exit 41
  }
done

if grep -Fq "Argument for '--moduleResolution' option must be" "$delivery_log"; then
  echo 'ERROR: legacy Sonar TypeScript module-resolution failure remains.' >&2
  exit 42
fi
if grep -Eq 'Skipped [1-9][0-9]* file\(s\) because they were not part of any tsconfig\.json' \
  "$delivery_log"; then
  echo 'ERROR: Sonar still skipped TypeScript sources outside its standalone configs.' >&2
  exit 43
fi
if grep -Fq 'refusing to build/push from a dirty worktree' "$delivery_log"; then
  echo 'ERROR: Jenkins control artifacts still violate the clean-worktree gate.' >&2
  exit 44
fi
echo 'PASS: Sonar TypeScript compatibility and Jenkins worktree cleanliness verified.'

digest_name="harbor-digests-${commit}.tsv"
digest_report="$HOME/Downloads/zabisa-${digest_name}"

curl "${curl_auth[@]}" \
  "$jenkins_url/job/$target_job/job/$branch_job/$delivery_build/artifact/build/image-evidence/$digest_name" \
  >"$digest_report"

python3 - "$digest_report" "$commit" <<'PY'
import csv
import re
import sys

path, commit = sys.argv[1:]
with open(path, encoding="utf-8", newline="") as stream:
    rows = list(csv.DictReader(stream, delimiter="\t"))

expected = {
    "api-gateway", "identity", "content", "student", "tahfidz",
    "academic", "donation", "notification", "admin-web",
}
assert len(rows) == 9, f"expected 9 digest rows, got {len(rows)}"
assert {row["name"] for row in rows} == expected, "image target set mismatch"
for row in rows:
    assert row["revision"] == commit, f"revision mismatch for {row['name']}"
    assert re.fullmatch(
        rf"harbor-dt\.co\.id/devops-apps/zabisa/{re.escape(row['name'])}@sha256:[0-9a-f]{{64}}",
        row["digest_ref"],
    ), f"invalid digest reference for {row['name']}"

print("PASS: nine Harbor digest references verified.")
PY

disable_parent

echo
echo "===== FINAL DT4.3/DT4.4 RESULT ====="
echo "Source commit     : $commit"
echo "Readiness build   : #$readiness_build SUCCESS"
echo "Delivery build    : #$delivery_build SUCCESS"
echo "Harbor images     : 9 immutable SHA tags verified"
echo "GitOps publish    : 16 image references committed to zabisa-super-app-gitops/main"
echo "Digest report     : $digest_report"
sha256sum "$digest_report"
echo "Jenkins parent    : DISABLED"
echo "Migration         : NOT RUN"
echo "ArgoCD sync       : NOT RUN"
echo "PASS: DT4.3 READINESS AND DT4.4 HARBOR DELIVERY COMPLETE"
