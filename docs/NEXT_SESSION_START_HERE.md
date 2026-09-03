# Next Session — Start Here

Use this file to prevent context mismatch.

## 1. Confirm repository

```bash
cd ~/project-homelab/zabisa-super-app
git status
git branch --show-current
git log --oneline -5
git tag --list 'phase-3.7.6-*'
```

Expected lock tag:

```text
phase-3.7.6-locked-2026-08-31
```

## 2. Read in this order

1. `docs/PROJECT_STATE.md`
2. `docs/KNOWN_LIMITATIONS.md`
3. `docs/DEVELOPMENT_ROADMAP.md`
4. `docs/ARCHITECTURE.md`
5. the domain document relevant to the next task.

## 3. Runtime check

```bash
docker compose ps
./scripts/verify-admin-runtime.sh
```

## 4. Minimum engineering baseline

Before modifying critical behavior:

```bash
npm run admin:form-invariant
npm run admin:source-invariants
npm run admin:session-invariant
npm run phase37:invariants
```

If touching Backoffice critical paths, run:

```bash
npm run admin:typecheck
npm run lint --workspace=@zabisa/admin-web -- --max-warnings=0
npm run admin:build
npm run admin:e2e
```

If touching API contracts/security:

```bash
npm run phase37:contracts
npm run phase34:verify
npm run phase36:audit
npm run phase37:audit
```

If touching Guardian/mobile-facing behavior:

```bash
npm run demo:verify
npm run mobile:quality
```

## 5. Architecture invariants that must not regress

- MySQL, not PostgreSQL.
- No direct cross-service DB queries.
- Backend RBAC is authoritative.
- Guardian access requires APPROVED relationship.
- Strict JSON decoder remains strict.
- Session query shape stays centralized.
- No async `event.currentTarget.reset()` form bug.
- Next standalone uses generated server, not `next start`.
- Local Backoffice cookie may be insecure only for local HTTP; production must
  use Secure cookie.
- Playwright system Chrome, trace/screenshot failures, video off.
- Audit verifier streams large responses through stdin.
- Zabisa Metro host port 8082; do not kill the unrelated port-8081 process.
- Do not `pm clear` the verified OPPO workflow.
- Do not run `npm audit fix --force`.

## 6. Current phase

Validate and finish:

**Phase 3.8 — GitHub CI and repository quality gate**

Run `./scripts/quality-gate.sh`, push the Phase 3.8 branch, enable Sonar only
after its URL/token are configured, then require both GitHub jobs on `main`.
Do not start FCM/payment-provider work before CI is reproducible.
