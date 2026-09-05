#!/usr/bin/env bash

set -Eeuo pipefail
set +x
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHA="${1:-}"
RENDERED="${2:-$ROOT/build/gitops-rendered}"
GITOPS_REPOSITORY="${GITOPS_REPOSITORY:-https://github.com/ditasetyakurniawan-droid/zabisa-super-app-gitops.git}"
GITOPS_BRANCH="${GITOPS_BRANCH:-main}"
GITOPS_PATH="${GITOPS_PATH:-apps/zabisa/overlays/dt}"

if [[ ! "$SHA" =~ ^[0-9a-f]{40}$ ]]; then
  echo 'ERROR: GitOps publication requires the full lowercase source Git SHA.' >&2
  exit 64
fi
[[ -d "$RENDERED/manifests" ]] || {
  echo "ERROR: rendered manifest directory is missing: $RENDERED/manifests" >&2
  exit 65
}
[[ "$(<"$RENDERED/SOURCE_REVISION")" == "$SHA" ]] || {
  echo 'ERROR: rendered source revision does not match the requested SHA.' >&2
  exit 66
}
[[ -n "${GITOPS_USERNAME:-}" && -n "${GITOPS_PASSWORD:-}" ]] || {
  echo 'ERROR: GITOPS_USERNAME and GITOPS_PASSWORD must come from Jenkins credentials.' >&2
  exit 67
}
[[ "$GITOPS_REPOSITORY" == https://github.com/*/*.git ]] || {
  echo 'ERROR: GITOPS_REPOSITORY must be an HTTPS github.com repository URL.' >&2
  exit 68
}
[[ "$GITOPS_BRANCH" == main ]] || {
  echo 'ERROR: DT GitOps publication is restricted to the main branch.' >&2
  exit 69
}
[[ "$GITOPS_PATH" == apps/zabisa/overlays/dt ]] || {
  echo 'ERROR: unexpected GitOps destination path.' >&2
  exit 70
}

temp_dir="$(mktemp -d /tmp/zabisa-gitops-publish.XXXXXX)"
cleanup() {
  set +e
  unset GITOPS_USERNAME GITOPS_PASSWORD
  if [[ -d "$temp_dir" && "$temp_dir" == /tmp/zabisa-gitops-publish.* ]]; then
    rm -rf -- "$temp_dir"
  fi
}
trap cleanup EXIT

askpass="$temp_dir/git-askpass.sh"
cat >"$askpass" <<'ASKPASS'
#!/bin/sh
case "$1" in
  *Username*) printf '%s\n' "$GITOPS_USERNAME" ;;
  *Password*) printf '%s\n' "$GITOPS_PASSWORD" ;;
  *) exit 1 ;;
esac
ASKPASS
chmod 700 "$askpass"

export GIT_ASKPASS="$askpass"
export GIT_TERMINAL_PROMPT=0

checkout="$temp_dir/repository"
git clone --quiet --branch "$GITOPS_BRANCH" --single-branch \
  "$GITOPS_REPOSITORY" "$checkout"

destination="$checkout/$GITOPS_PATH"
mkdir -p "$destination"
find "$destination" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
cp -a "$RENDERED"/. "$destination"/

cd "$checkout"
git diff --check
git add -- "$GITOPS_PATH"

if git diff --cached --quiet; then
  published="$(git rev-parse HEAD)"
  echo "[gitops] PASS: published source=$SHA gitops_commit=$published (already current)"
  echo '[gitops] ArgoCD sync was not requested.'
  exit 0
fi

git -c user.name="${GITOPS_COMMIT_NAME:-Zabisa Jenkins}" \
    -c user.email="${GITOPS_COMMIT_EMAIL:-jenkins@zabisa.local}" \
    commit --quiet -m "deploy(dt): publish Zabisa ${SHA:0:12}"

git push --quiet origin "HEAD:$GITOPS_BRANCH"
published="$(git rev-parse HEAD)"
remote="$(git ls-remote origin "refs/heads/$GITOPS_BRANCH" | awk '{print $1}')"
[[ "$remote" == "$published" ]] || {
  echo 'ERROR: GitOps remote verification failed after push.' >&2
  exit 71
}

echo "[gitops] PASS: published source=$SHA gitops_commit=$published"
echo "[gitops] path=$GITOPS_PATH branch=$GITOPS_BRANCH"
echo '[gitops] ArgoCD sync was not requested.'
