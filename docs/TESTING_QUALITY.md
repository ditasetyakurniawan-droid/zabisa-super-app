# Testing and Quality Gates

## Dua gate lokal wajib

Developer menjalankan dua tingkat pemeriksaan sebelum push:

```bash
./scripts/developer-check.sh quick
./scripts/developer-check.sh full
```

`quick` menjalankan invariant/preflight, lockfile, lint, typecheck dan unit test
Admin/Mobile. `full` menjalankan `scripts/quality-gate.sh`, sama dengan langkah
repository quality gate di GitHub. Panduan dan padanan manual tersedia di
`DEVELOPER_GUIDE_ID.md`.

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

At the DT58 lock, the reviewed local run passed 11 Mobile suites / 37 tests and
the Admin run passed 1 suite / 11 tests. GitHub and Jenkins remain the
authoritative remote evidence.

### Coverage warning

Sonar New Code coverage reached 77.4% in the remediation evidence and the final
Jenkins delivery passed the dedicated 75% project gate. Overall coverage and
New Code coverage are different metrics; developers must not use one as a
substitute for the other.

## SonarQube

Sonar configuration imports Admin and Mobile LCOV and the final private Quality
Gate passed in Jenkins delivery `#19`.

Locked policy:

- New Code coverage minimum 75% on the dedicated Zabisa gate;
- no changes to other gate conditions without an explicit review;
- no blocker/critical vulnerabilities;
- meaningful behavioural coverage improvement;
- controlled duplication;
- reviewed security hotspots;
- do not chase artificial 100% coverage or exclude business logic.

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
