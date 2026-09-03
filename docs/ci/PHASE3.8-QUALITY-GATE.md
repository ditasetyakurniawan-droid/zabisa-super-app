# Phase 3.8 — Reproducible CI and Quality Gate

## Goal

Turn the Phase 3.7.6 development lock and Hotfix 0.3.7 into a repeatable pull
request contract. The gate must fail on formatting, compilation, type, lint,
test, build, vulnerability, secret-hygiene, browser-regression, or SonarQube
quality failures.

## Local gate

Install the exact Node dependency graph, use the Go toolchain declared in
`go.mod`, then run:

```bash
npm ci --workspaces --include-workspace-root --no-audit --no-fund
./scripts/quality-gate.sh
```

The Go gate deliberately targets only `./packages/go/...` and `./services/...`.
Using `./...` from the repository root is prohibited because it can discover
unrelated Go packages nested under `node_modules`.

## GitHub checks

`.github/workflows/ci.yml` provides two required jobs:

1. `Go, Node, Mobile, Backoffice, Sonar`
   - offline repository invariants and secret hygiene;
   - scoped Go format, vet, tests and coverage;
   - locked Node install;
   - Backoffice and mobile lint/typecheck;
   - mobile Jest coverage;
   - Backoffice production build;
   - production npm dependency audit;
   - reachable Go vulnerability analysis;
   - optional SonarQube scan with quality-gate wait.
2. `Backoffice Browser E2E`
   - ephemeral Docker Compose stack and local MySQL volume;
   - development-only seed;
   - the real Chrome 12-scenario matrix;
   - failure logs, traces, and screenshots retained for 14 days;
   - unconditional cleanup of the ephemeral stack and volume.

The browser job never points at DT MySQL. It uses the Compose-local `mysql`
hostname and destroys only its ephemeral runner volume after the job.

## SonarQube configuration

Sonar analysis is opt-in until repository connectivity and credentials exist.
Configure:

- repository variable `SONAR_ENABLED=true`;
- repository variable `SONAR_HOST_URL` with the SonarQube server URL;
- repository secret `SONAR_TOKEN` with an analysis-only token.

When SonarQube is reachable only from the homelab/private network, use an
appropriately isolated self-hosted GitHub runner. Do not expose SonarQube or its
token merely to support a public hosted runner.

Imported reports:

- `coverage/go-cover.out`;
- `coverage/go-test-report.json`;
- `apps/mobile/coverage/lcov.info`.

Tests, native generated projects, dependencies, build output, and migrations
are classified/excluded explicitly. Backoffice production source is not hidden
from coverage; its missing unit coverage remains visible technical debt.

## Branch protection

After the first successful workflow run, protect `main` and require both job
checks above. Also require the branch to be current before merge and prohibit
force-push/deletion of `main`.

## Dependency policy

Dependabot opens bounded weekly pull requests for Go modules, npm, and GitHub
Actions. Dependency updates must pass the same quality gate; do not use
`npm audit fix --force`.

`npm run audit:production` stores the complete report in
`coverage/npm-audit.json` and fails closed for every unapproved high or critical
root advisory. Two `image-size` denial-of-service advisories are accepted only
until 2026-12-01 because they are transitive through the React Native Metro
build toolchain and upstream currently publishes no patched version:

- `GHSA-W3RX-R6R6-PGPR`;
- `GHSA-5P2G-FCMC-QVQQ`.

This is not a package-name or severity-wide suppression. Any new high/critical
advisory still blocks immediately, and the two entries automatically block
after their expiry. Review Metro/React Native releases and remove the exception
as soon as a tested patched dependency path exists.

## Scope boundary

This phase changes no MySQL schema, migration, Vault policy, production secret,
or runtime deployment topology. The three operator-side MySQL provisioning
files created outside the locked source remain a separate review/commit.
