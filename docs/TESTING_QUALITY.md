# Testing and Quality Gates

## Backoffice

Required gates:

```bash
npm run admin:form-invariant
npm run admin:source-invariants
npm run admin:session-invariant
npm run admin:typecheck
npm run lint --workspace=@zabisa/admin-web -- --max-warnings=0
npm run admin:build
npm run admin:e2e
```

Current browser matrix: **12/12 passed at lock**.

## Backend

Scoped Go tests should cover platform packages and affected services. Current
service packages still have sparse unit-test depth in places; a package showing
`[no test files]` is not evidence of complete test coverage.

The canonical gate is:

```bash
./scripts/go-quality.sh
```

It emits Sonar-compatible coverage and test-execution reports without scanning
Go packages nested under `node_modules`.

## Contract/regression suites

Important existing scripts include:

```bash
npm run phase34:verify
npm run phase35:verify
npm run phase35:guardian-verify
npm run phase36:audit
npm run phase37:invariants
npm run phase37:contracts
npm run phase37:audit
npm run demo:verify
```

## Runtime regression

```bash
./scripts/verify-admin-runtime.sh
./scripts/verify-admin-session-cache.sh apps/admin-web
```

The runtime verifier repeatedly requests protected Backoffice pages under an
authenticated session.

## Mobile

```bash
npm run mobile:quality
```

At the lock, mobile quality passes with six Jest suites and Guardian API E2E.

### Coverage warning

Overall mobile statement coverage at the latest lock remained around the low
20% range, with many screen files at zero unit coverage.

This is accepted only as the current development baseline. It is **not** a
target quality level for production release.

## SonarQube

Sonar configuration exists and should remain aligned with mobile LCOV. The
final CI quality gate is future work.

Desired policy:

- no blocker/critical vulnerabilities;
- meaningful coverage improvement;
- controlled duplication;
- reviewed security hotspots;
- do not chase artificial 100% coverage.

The Phase 3.8 report paths are:

- Go coverage: `coverage/go-cover.out`;
- Go test execution: `coverage/go-test-report.json`;
- npm production dependency audit: `coverage/npm-audit.json`;
- mobile LCOV: `apps/mobile/coverage/lcov.info`.

The Go test execution report is newline-delimited JSON (NDJSON), not one JSON
document. Offline preflight validates each non-empty report line independently.

See `docs/ci/PHASE3.8-QUALITY-GATE.md` for GitHub variables, secrets, and branch
protection requirements.

## Browser diagnostics

Playwright keeps:

- trace on failure;
- screenshot on failure;
- video disabled.

Use traces when browser behavior and API scripts disagree.
