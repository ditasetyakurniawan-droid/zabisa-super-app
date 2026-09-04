#!/usr/bin/env bash

set -Eeuo pipefail
set +x
umask 077

mode="${1:---plan}"
source_job="tropical-management-v1"
target_job="zabisa-super-app-v1"
scm_credentials="github-credentials-id"
repository_url="https://github.com/ditasetyakurniawan-droid/zabisa-super-app.git"
script_path="Jenkinsfile"
jenkins_ssh_target="${JENKINS_SSH_TARGET:-ubuntu@192.168.100.57}"
jenkins_local_port="${JENKINS_LOCAL_PORT:-18080}"
jenkins_url="http://127.0.0.1:${jenkins_local_port}"

temp_dir=""
tunnel_pid=""

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/bootstrap-zabisa-jenkins-job.sh --plan
  DT42_CONFIRM=CREATE-DISABLED-ZABISA-JOB \
    ./scripts/bootstrap-zabisa-jenkins-job.sh --apply
  ./scripts/bootstrap-zabisa-jenkins-job.sh --verify

This clones the proven tropical-management-v1 Multibranch job structure,
replaces only the repository/source identity, and creates Zabisa disabled.
It never enables, indexes, or starts a build.
USAGE
}

case "$mode" in
  --plan|--apply|--verify) ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 64 ;;
esac

cleanup() {
  set +e

  if [[ -n "${tunnel_pid:-}" ]] &&
     kill -0 "$tunnel_pid" 2>/dev/null; then
    kill "$tunnel_pid" 2>/dev/null || true
    wait "$tunnel_pid" 2>/dev/null || true
  fi

  if [[ -n "${temp_dir:-}" &&
        -d "$temp_dir" &&
        "$temp_dir" == /tmp/zabisa-jenkins-job.* ]]; then
    rm -rf -- "$temp_dir"
  fi

  unset jenkins_api_token crumb_header crumb_name crumb_value 2>/dev/null || true
}

failure_report() {
  rc=$?
  set +e
  echo
  echo "[jenkins-job] ERROR: mode=$mode rc=$rc command=$BASH_COMMAND" >&2
  echo '[jenkins-job] No build, image push, deployment, migration or ArgoCD sync was requested.' >&2
  exit "$rc"
}

trap cleanup EXIT
trap failure_report ERR

command -v ssh >/dev/null || { echo 'ERROR: ssh is required.' >&2; exit 10; }
command -v curl >/dev/null || { echo 'ERROR: curl is required.' >&2; exit 11; }
command -v python3 >/dev/null || { echo 'ERROR: python3 is required.' >&2; exit 12; }

[[ "$jenkins_local_port" =~ ^[0-9]+$ ]] &&
  (( jenkins_local_port >= 1024 && jenkins_local_port <= 65535 )) || {
    echo 'ERROR: JENKINS_LOCAL_PORT must be an unprivileged TCP port.' >&2
    exit 13
  }

temp_dir="$(mktemp -d /tmp/zabisa-jenkins-job.XXXXXX)"
netrc_file="$temp_dir/jenkins.netrc"
source_xml="$temp_dir/source.xml"
rendered_xml="$temp_dir/zabisa-disabled.xml"
verified_xml="$temp_dir/verified.xml"

echo "===== JENKINS JOB CONTROL PLAN ====="
echo "Mode           : $mode"
echo "Jenkins        : $jenkins_ssh_target via encrypted SSH tunnel"
echo "Source pattern : $source_job"
echo "Target job     : $target_job"
echo "Job type       : Multibranch Pipeline"
echo "SCM credential : $scm_credentials"
echo "Repository     : $repository_url"
echo "Script path    : $script_path"
echo "Initial state  : DISABLED"
echo "Build trigger  : NOT REQUESTED"
echo "Credential values: NOT DISPLAYED"

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

  kill -0 "$tunnel_pid" 2>/dev/null || {
    echo 'ERROR: Jenkins SSH tunnel stopped.' >&2
    exit 20
  }

  [[ "$attempt" -lt 30 ]] || {
    echo 'ERROR: Jenkins HTTP endpoint did not become ready.' >&2
    exit 21
  }
  sleep 1
done

read -r -p 'Jenkins username: ' jenkins_username
read -r -s -p 'Jenkins API token (hidden): ' jenkins_api_token
echo

[[ -n "$jenkins_username" && "$jenkins_username" != *[[:space:]]* ]] || {
  echo 'ERROR: Jenkins username is empty or contains whitespace.' >&2
  exit 22
}
[[ -n "$jenkins_api_token" && "$jenkins_api_token" != *[[:space:]]* ]] || {
  echo 'ERROR: Jenkins API token is empty or contains whitespace.' >&2
  exit 23
}

cat >"$netrc_file" <<NETRC
machine 127.0.0.1
login $jenkins_username
password $jenkins_api_token
NETRC
chmod 600 "$netrc_file"
unset jenkins_api_token

curl_auth=(
  --silent
  --show-error
  --fail
  --netrc-file "$netrc_file"
  --connect-timeout 5
  --max-time 30
)

whoami="$(curl "${curl_auth[@]}" "$jenkins_url/whoAmI/api/json")"
python3 -c '
import json, sys
data = json.load(sys.stdin)
assert data.get("authenticated") is True, "Jenkins identity is not authenticated"
print(f"Authenticated as: {data.get(chr(110)+chr(97)+chr(109)+chr(101), chr(117)+chr(110)+chr(107)+chr(110)+chr(111)+chr(119)+chr(110))}")
' <<<"$whoami"
unset whoami

crumb_header="$(
  curl "${curl_auth[@]}" \
    "$jenkins_url/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,%22:%22,//crumb)" \
    2>/dev/null || true
)"

post_headers=(-H 'Content-Type: application/xml')
if [[ -n "$crumb_header" && "$crumb_header" == *:* ]]; then
  crumb_name="${crumb_header%%:*}"
  crumb_value="${crumb_header#*:}"
  post_headers+=(-H "$crumb_name:$crumb_value")
  echo "CSRF crumb     : PRESENT"
else
  echo "CSRF crumb     : not-required/unavailable"
fi

target_status="$(
  curl --silent --output /dev/null --write-out '%{http_code}' \
    --netrc-file "$netrc_file" \
    --connect-timeout 5 --max-time 30 \
    "$jenkins_url/job/$target_job/config.xml" || true
)"

if [[ "$mode" == "--verify" ]]; then
  [[ "$target_status" == "200" ]] || {
    echo "ERROR: target job does not exist or is unreadable (HTTP $target_status)." >&2
    exit 30
  }

  curl "${curl_auth[@]}" \
    "$jenkins_url/job/$target_job/config.xml" >"$verified_xml"

  python3 - "$verified_xml" "$repository_url" "$scm_credentials" "$script_path" <<'PY'
import sys
import xml.etree.ElementTree as ET

path, expected_remote, expected_credentials, expected_script = sys.argv[1:]
root = ET.parse(path).getroot()

def local(tag):
    return tag.rsplit("}", 1)[-1]

def values(name):
    return [(node.text or "").strip() for node in root.iter() if local(node.tag) == name]

def nodes(name):
    return [node for node in root.iter() if local(node.tag) == name]

assert "WorkflowMultiBranchProject" in local(root.tag), local(root.tag)
assert values("remote") == [expected_remote], values("remote")
assert values("credentialsId") == [expected_credentials], values("credentialsId")
assert values("scriptPath") == [expected_script], values("scriptPath")
assert values("disabled") == ["true"], values("disabled")
assert all(len(node) == 0 for node in nodes("triggers")), "automatic triggers remain"
print("[jenkins-job] PASS: Zabisa Multibranch job exists and remains disabled.")
PY
  exit 0
fi

[[ "$target_status" == "404" ]] || {
  echo "ERROR: target job already exists or status is ambiguous (HTTP $target_status)." >&2
  echo 'Use --verify; this bootstrap never overwrites an existing job.' >&2
  exit 31
}

curl "${curl_auth[@]}" \
  "$jenkins_url/job/$source_job/config.xml" >"$source_xml"

python3 - \
  "$source_xml" \
  "$rendered_xml" \
  "$repository_url" \
  "$scm_credentials" \
  "$script_path" <<'PY'
import sys
import xml.etree.ElementTree as ET

source, destination, repository, credentials, script_path = sys.argv[1:]
tree = ET.parse(source)
root = tree.getroot()

def local(tag):
    return tag.rsplit("}", 1)[-1]

def nodes(name):
    return [node for node in root.iter() if local(node.tag) == name]

assert "WorkflowMultiBranchProject" in local(root.tag), local(root.tag)

remotes = nodes("remote")
credential_nodes = nodes("credentialsId")
script_nodes = nodes("scriptPath")
source_ids = [node for node in nodes("id") if node.text]

assert len(remotes) == 1, f"expected one SCM remote, got {len(remotes)}"
assert len(credential_nodes) == 1, (
    f"expected one SCM credential reference, got {len(credential_nodes)}"
)
assert len(script_nodes) == 1, f"expected one scriptPath, got {len(script_nodes)}"

remotes[0].text = repository
credential_nodes[0].text = credentials
script_nodes[0].text = script_path

if source_ids:
    source_ids[0].text = "zabisa-super-app-v1-source"

descriptions = nodes("description")
if descriptions:
    descriptions[0].text = (
        "Zabisa existing-platform Multibranch job. Created disabled; "
        "manual approval is required before first indexing/build."
    )

disabled_nodes = [node for node in root if local(node.tag) == "disabled"]
if disabled_nodes:
    disabled = disabled_nodes[0]
else:
    disabled = ET.SubElement(root, "disabled")
disabled.text = "true"

for triggers in nodes("triggers"):
    for child in list(triggers):
        triggers.remove(child)

tree.write(destination, encoding="utf-8", xml_declaration=True)

print("[jenkins-job] Rendered from existing Multibranch pattern")
print(f"[jenkins-job] repository={repository}")
print(f"[jenkins-job] credentialsId={credentials}")
print(f"[jenkins-job] scriptPath={script_path}")
print("[jenkins-job] disabled=true")
print("[jenkins-job] automatic triggers=none")
print("[jenkins-job] credential values=NOT DISPLAYED")
PY

echo "Rendered SHA256: $(sha256sum "$rendered_xml" | awk '{print $1}')"

if [[ "$mode" == "--plan" ]]; then
  echo '[jenkins-job] PLAN PASS: disabled job config rendered; Jenkins was not mutated.'
  exit 0
fi

[[ "${DT42_CONFIRM:-}" == "CREATE-DISABLED-ZABISA-JOB" ]] || {
  echo 'ERROR: set DT42_CONFIRM=CREATE-DISABLED-ZABISA-JOB for --apply.' >&2
  exit 40
}

echo
echo "===== CREATE DISABLED ZABISA JOB ====="

target_job_encoded="$(
  python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' \
    "$target_job"
)"

create_status="$(
  curl --silent --show-error \
    --output "$temp_dir/create-response.txt" \
    --write-out '%{http_code}' \
    --netrc-file "$netrc_file" \
    --connect-timeout 5 --max-time 30 \
    "${post_headers[@]}" \
    --data-binary "@$rendered_xml" \
    -X POST "$jenkins_url/createItem?name=$target_job_encoded" || true
)"

[[ "$create_status" == "200" || "$create_status" == "302" ]] || {
  echo "ERROR: Jenkins createItem returned HTTP $create_status." >&2
  exit 41
}

curl "${curl_auth[@]}" \
  "$jenkins_url/job/$target_job/config.xml" >"$verified_xml"

python3 - "$verified_xml" "$repository_url" "$scm_credentials" "$script_path" <<'PY'
import sys
import xml.etree.ElementTree as ET

path, expected_remote, expected_credentials, expected_script = sys.argv[1:]
root = ET.parse(path).getroot()

def local(tag):
    return tag.rsplit("}", 1)[-1]

def values(name):
    return [(node.text or "").strip() for node in root.iter() if local(node.tag) == name]

def nodes(name):
    return [node for node in root.iter() if local(node.tag) == name]

assert "WorkflowMultiBranchProject" in local(root.tag), local(root.tag)
assert values("remote") == [expected_remote], values("remote")
assert values("credentialsId") == [expected_credentials], values("credentialsId")
assert values("scriptPath") == [expected_script], values("scriptPath")
assert values("disabled") == ["true"], values("disabled")
assert all(len(node) == 0 for node in nodes("triggers")), "automatic triggers remain"
print("[jenkins-job] PASS: disabled Zabisa Multibranch job created and verified.")
PY

echo "Job URL       : http://192.168.100.57:8080/job/$target_job/"
echo "Initial state : DISABLED"
echo "Index/build   : NOT REQUESTED"
echo "Docker/Harbor : NOT TOUCHED"
