#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

MODE="quick"
if [[ "${1:-}" == "--full" ]]; then
  MODE="full"
elif [[ -n "${1:-}" ]]; then
  echo "usage: $0 [--full]" >&2
  exit 64
fi

fail() { printf '[preflight] ERROR: %s\n' "$*" >&2; exit 1; }
pass() { printf '[preflight] OK: %s\n' "$*"; }
skip() { printf '[preflight] SKIP: %s\n' "$*"; }

printf '[preflight] repository: %s\n' "$ROOT"
printf '[preflight] mode: %s (offline; no Kubernetes API access required)\n' "$MODE"

# 1. Git integrity / whitespace.
if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git diff --check
  pass 'git diff --check'

  tracked_generated="$(
    git ls-files \
      | grep -E '(^|/)(node_modules|\.gradle|\.cxx|test-results|playwright-report|__pycache__)(/|$)|\.tsbuildinfo$|\.bak(-[^/]*)?$|\.py[co]$' \
      | while IFS= read -r f; do [[ -e "$f" ]] && printf '%s\n' "$f"; done \
      || true
  )"
  if [[ -n "$tracked_generated" ]]; then
    printf '%s\n' "$tracked_generated" >&2
    fail 'generated/cache artifacts still exist in the worktree while tracked by Git'
  fi
  pass 'tracked generated/cache artifacts are absent from worktree (pending deletions are allowed)'
else
  skip 'Git checks (not a Git worktree or git unavailable)'
fi

# 2. Deployment isolation invariants.
if grep -RIn --include='*.yaml' --include='*.yml' 'namespace:[[:space:]]*zabisa-dt' deploy >/tmp/zabisa-preflight-old-ns.txt 2>/dev/null; then
  cat /tmp/zabisa-preflight-old-ns.txt >&2
  fail 'stale namespace zabisa-dt remains under deploy/'
fi
pass 'no stale zabisa-dt namespace in deploy/'

grep -Eq '^[[:space:]]*name:[[:space:]]*zabisa-app[[:space:]]*$' deploy/kubernetes/base/platform.yaml \
  || fail 'namespace zabisa-app is not declared in platform.yaml'
pass 'namespace zabisa-app declared'

# Keep the API Gateway process health contract synchronized with its Pod probes.
grep -Fq 'case "/health/live":' services/api-gateway/handler.go \
  || fail 'API Gateway liveness route is missing'
grep -Fq 'case "/health/ready":' services/api-gateway/handler.go \
  || fail 'API Gateway readiness route is missing'
grep -Eq '^[[:space:]]*path:[[:space:]]*/health/live[[:space:]]*$' deploy/kubernetes/base/api-gateway.yaml \
  || fail 'API Gateway liveness probe path is missing'
grep -Eq '^[[:space:]]*path:[[:space:]]*/health/ready[[:space:]]*$' deploy/kubernetes/base/api-gateway.yaml \
  || fail 'API Gateway readiness probe path is missing'
pass 'API Gateway health routes match Kubernetes probes'

# NetworkPolicy guardrails introduced by Hotfix 0.2.
grep -q 'name: default-deny' deploy/kubernetes/base/platform.yaml \
  || fail 'default-deny NetworkPolicy missing'
grep -q 'name: allow-dns-egress' deploy/kubernetes/base/platform.yaml \
  || fail 'DNS egress NetworkPolicy missing'
grep -q 'name: allow-mysql-egress' deploy/kubernetes/base/platform.yaml \
  || fail 'MySQL egress NetworkPolicy missing'
grep -q '192.168.100.70/32' deploy/kubernetes/base/platform.yaml \
  || fail 'DT MySQL CIDR 192.168.100.70/32 missing from NetworkPolicy'
pass 'NetworkPolicy baseline invariants'

./scripts/verify-db-dt-abstraction.sh || fail 'external MySQL DNS abstraction invariants failed'
pass 'external MySQL DNS abstraction invariants'

./scripts/verify-db-security-boundary.sh || fail 'DB TLS/runtime-migrator boundary invariants failed'
pass 'DB TLS + runtime/migrator boundary invariants'

./scripts/verify-zabisa-mysql-vault-provision.sh --source \
  || fail 'MySQL/Vault provisioning source invariants failed'
pass 'MySQL/Vault provisioning source invariants'

# Vault Agent Injector guardrails introduced by Hotfix 0.3.
./scripts/verify-vault-injector.sh || fail 'Vault Agent Injector invariants failed'
pass 'Vault Agent Injector + per-service identity invariants'

./scripts/verify-dt2-source.sh || fail 'DT2 source invariants failed'
pass 'DT2 Vault/CA credential-canary source invariants'

./scripts/verify-dt3-source.sh || fail 'DT3 source invariants failed'
pass 'DT3 controlled migration-readiness source invariants'

# 3. Tracked secret hygiene.
./scripts/verify-secret-hygiene.sh || fail 'tracked secret hygiene failed'
pass 'tracked secret hygiene'

# 4. Parse source formats that have standard-library parsers.
if command -v node >/dev/null 2>&1; then
  json_source_files() {
    if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      git ls-files -z -- '*.json'
    else
      find . \
        -path './node_modules' -prune -o \
        -path './.git' -prune -o \
        -path '*/coverage' -prune -o \
        -path '*/.next' -prune -o \
        -path '*/test-results' -prune -o \
        -path '*/playwright-report' -prune -o \
        -type f -name '*.json' -print0
    fi
  }

  while IFS= read -r -d '' f; do
    node -e 'JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"))' "$f" \
      || fail "invalid JSON: $f"
  done < <(json_source_files)
  pass 'tracked/source JSON syntax'

  if [[ -s coverage/go-test-report.json ]]; then
    node -e '
      const fs = require("fs");
      const lines = fs.readFileSync(process.argv[1], "utf8").split(/\r?\n/).filter(Boolean);
      if (lines.length === 0) throw new Error("empty Go test report");
      lines.forEach((line, index) => {
        try { JSON.parse(line); }
        catch (error) { throw new Error(`invalid NDJSON at line ${index + 1}: ${error.message}`); }
      });
    ' coverage/go-test-report.json || fail 'invalid Go test NDJSON report'
    pass 'Go test NDJSON report syntax'
  fi

  node ./scripts/verify-node-lockfile.mjs || fail 'Node lockfile/workspace synchronization failed'
  pass 'Node lockfile/workspace synchronization'
else
  skip 'JSON parse checks (node unavailable)'
fi

./scripts/verify-image-pipeline.sh || fail 'immutable image/GitOps pipeline invariants failed'
pass 'immutable image/GitOps pipeline invariants'

./scripts/verify-quality-gate.sh || fail 'CI/Sonar quality gate invariants failed'
pass 'CI/Sonar quality gate invariants'

while IFS= read -r -d '' f; do
  bash -n "$f" || fail "invalid shell syntax: $f"
done < <(find scripts -type f -name '*.sh' -print0)
pass 'shell script syntax'

# Offline YAML syntax validation when a local parser is already installed.
if command -v ruby >/dev/null 2>&1; then
  while IFS= read -r -d '' f; do
    ruby -e 'require "yaml"; YAML.load_stream(File.read(ARGV[0]))' "$f" \
      || fail "invalid YAML: $f"
  done < <(find deploy .github -type f \( -name '*.yaml' -o -name '*.yml' \) -print0)
  pass 'YAML syntax via local Ruby/Psych'
elif command -v python3 >/dev/null 2>&1 && python3 -c 'import yaml' >/dev/null 2>&1; then
  while IFS= read -r -d '' f; do
    python3 -c 'import sys,yaml; list(yaml.safe_load_all(open(sys.argv[1], encoding="utf-8")))' "$f" \
      || fail "invalid YAML: $f"
  done < <(find deploy .github -type f \( -name '*.yaml' -o -name '*.yml' \) -print0)
  pass 'YAML syntax via local PyYAML'
elif command -v yamllint >/dev/null 2>&1; then
  yamllint deploy .github || fail 'yamllint failed'
  pass 'YAML syntax via yamllint'
else
  skip 'YAML parser not installed; cluster-independent semantic invariants still checked'
fi

# 5. Docker Compose parsing is local-only. Do not start containers.
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  docker compose config --quiet || fail 'docker compose config failed'
  pass 'docker compose config'
else
  skip 'docker compose config (Docker Compose unavailable)'
fi

if [[ "$MODE" == "full" ]]; then
  printf '[preflight] running full local quality checks; these do not contact Kubernetes.\n'

  if command -v npm >/dev/null 2>&1 && [[ -d node_modules ]]; then
    npm run typecheck --workspaces --if-present
    npm run lint --workspaces --if-present
    pass 'npm workspace typecheck + lint'
  else
    skip 'npm typecheck/lint (npm or local node_modules unavailable)'
  fi

  if command -v go >/dev/null 2>&1; then
    unformatted="$(gofmt -l services packages/go 2>/dev/null || true)"
    if [[ -n "$unformatted" ]]; then
      printf '%s\n' "$unformatted" >&2
      fail 'gofmt required'
    fi
    pass 'gofmt'

    # GOTOOLCHAIN=local prevents Go from downloading a different toolchain behind our back.
    if GOTOOLCHAIN=local go test ./packages/go/... ./services/...; then
      pass 'scoped Go tests'
    else
      fail 'scoped Go tests failed with local toolchain'
    fi
  else
    skip 'Go checks (go unavailable)'
  fi
fi

printf '[preflight] PASS: offline repository/deployment baseline is internally consistent.\n'
