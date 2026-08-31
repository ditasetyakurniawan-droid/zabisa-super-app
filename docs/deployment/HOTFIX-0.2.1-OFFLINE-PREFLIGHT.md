# Hotfix 0.2.1 — Offline Preflight Gate

Status: applied to working baseline.

## Why

`kubectl apply --dry-run=client` can still contact the Kubernetes API server for OpenAPI/discovery. When the DT API VIP is unreachable, the repository hotfix script previously aborted even though the manifest files themselves had not failed validation.

## Change

- `scripts/apply-hotfix-0.1-0.2.sh` is offline-safe by default.
- Cluster validation is explicit: `ZABISA_VALIDATE_CLUSTER=1 ...`.
- Added `scripts/preflight-offline.sh`.
- Added `npm run preflight:offline`, `npm run preflight:offline:full`, `make preflight`, and `make preflight-full`.

## Quick preflight (no cluster required)

Checks:

- Git whitespace integrity.
- no generated/cache artifacts tracked.
- namespace isolation (`zabisa-app`).
- NetworkPolicy hotfix invariants.
- basic tracked-secret hygiene.
- JSON syntax.
- shell syntax.
- YAML syntax if a local parser is available.
- Docker Compose parse if Docker Compose is available.

Run:

```bash
./scripts/preflight-offline.sh
```

## Full preflight

Adds workspace TypeScript lint/typecheck and Go tests where local dependencies/toolchain already exist. `GOTOOLCHAIN=local` is used so the check never silently downloads another Go toolchain.

```bash
./scripts/preflight-offline.sh --full
```

## When cluster access returns

Run API-backed schema/admission validation deliberately:

```bash
ZABISA_VALIDATE_CLUSTER=1 bash scripts/apply-hotfix-0.1-0.2.sh
```

This separation prevents a network outage from being misclassified as a source/manifests failure while keeping real cluster validation mandatory before deployment.
