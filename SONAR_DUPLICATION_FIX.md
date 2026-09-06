# Sonar duplication refactor

Source baseline: `94b7e51a175778247988ae7ab93f40430e12643c`

## What failed

The supplied Jenkins log shows that Go quality, Node quality, Python tests, and
the repository preflight completed before SonarScanner returned:

`QUALITY GATE STATUS: FAILED`

The scanner log does not include the failed condition values. The supplied
Sonar component table separately reports 55 duplicated blocks on new code, with
the largest concentrations in the database-backed service entrypoints.

## Refactor

- Centralized database open, runtime validation, migration-mode handling,
  health routes, server startup, and shutdown in `packages/go/platform/service`.
- Centralized JWT extraction, authenticated routing, RBAC permission checks,
  internal-service authentication, and guardian student scope in
  `packages/go/platform/access`.
- Removed the two byte-identical Academic and Tahfidz `student_scope.go` files.
- Centralized environment fallback and SQL nullable-value conversions.
- Updated the DB security invariant to recognize both the shared bootstrap and
  the legacy Identity bootstrap without weakening its APP_MODE checks.
- Added regression tests for authentication, authorization, internal-service
  access, guardian scope, shared bootstrap paths, health routing, and nullable
  conversions.
- Expanded branch coverage for staff/guardian authorization, rejected and
  unavailable student-service responses, bootstrap failure paths, environment
  fallback, and valid SQL nullable values after the first local coverage run.
- Added offline smoke coverage for all six refactored `buildService` functions;
  the tests verify dependency wiring and route construction without MySQL or a
  running HTTP server.
- Expanded behavioural coverage for guardian progress, account/login,
  notifications, donation completion, and successful/fallback deep-link flows.
- Removed the reported duplicated Go failure literals and API Gateway targets,
  replaced reported nested TypeScript ternaries with named decisions, and
  split runtime configuration validation into focused validation helpers.

## Local verification

Run from the repository root:

```bash
test -z "$(gofmt -l services packages/go)"
go vet ./packages/go/... ./services/...
go test -count=1 ./packages/go/... ./services/...
./scripts/preflight-offline.sh --full
```

Then commit the result and rerun the existing Jenkins job. Confirm the actual
new-code conditions through the Sonar Quality Gate page; a scanner exit code by
itself only proves that at least one condition failed.

## Verification completed while packaging

- `./scripts/preflight-offline.sh --full`: PASS. Go, npm, Git, and Docker checks
  were skipped automatically because those executables/worktrees were not
  available in the packaging runtime.
- `python -m py_compile ...`: PASS.
- `python -m unittest discover -s scripts -p 'test_*.py'`: 7 tests PASS.
- Local 10-line clone-window comparison: 160 to 38 literal-token groups
  (approximately 76% reduction). This is a directional regression check, not a
  substitute for the SonarQube CPD result.
