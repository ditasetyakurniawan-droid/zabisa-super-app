# Next Session — Start Here

Use this file to prevent context mismatch.

## 1. Confirm repository

```bash
cd ~/project-homelab/zabisa-super-app
git status
git branch --show-current
git log --oneline -5
./scripts/verify-dt42-jenkins-alignment.sh
./scripts/preflight-offline.sh
```

Expected repository state after the DT58 delivery lock:

```text
main synchronized with origin/main; clean worktree
Application/image lock: eee3284a6989857b6d4332f01d453763ccaf71b2
GitOps lock: 4fbc8b5db597cbdf73199f8f927eb0ac2cc544c9
Jenkins #18 readiness and #19 delivery: SUCCESS
Jenkins parent: DISABLED
Migration / Kubernetes / ArgoCD: NOT RUN
```

## 2. Read in this order

1. `docs/DEVELOPER_GUIDE_ID.md`
2. `docs/deployment/DT58-SONAR75-DELIVERY-LOCK.md`
3. `docs/deployment/CURRENT-STATE-AND-ROADMAP.md`
4. `docs/PROJECT_STATE.md`
5. `docs/runbook/JENKINS_DELIVERY.md`
6. `docs/KNOWN_LIMITATIONS.md`
7. the domain document relevant to the next task.

## 3. Runtime check

```bash
docker compose ps
./scripts/verify-admin-runtime.sh
```

## 4. Minimum engineering baseline

For ordinary development, use the canonical two-stage check:

```bash
./scripts/developer-check.sh quick
./scripts/developer-check.sh full
```

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

Current immutable delivery checkpoint:

**DT58 Sonar 75% delivery LOCKED; DT5 is next**

Jenkins readiness `#18` and delivery `#19` completed successfully for
application revision `eee3284a6989857b6d4332f01d453763ccaf71b2`. Harbor has
nine verified images; GitOps commit
`4fbc8b5db597cbdf73199f8f927eb0ac2cc544c9` has 16 immutable references across
12 manifests. The Jenkins parent job is disabled. Migration, Kubernetes apply
and ArgoCD sync have not run.

Phase 3.9.1 passed 25 mobile tests, Guardian API E2E, Backoffice source/runtime,
GitHub Engineering Quality Gate and physical Android installation/opening at
`f1ba18854af2a2a965090af41eb8bfc40a637cb1`. UI development may continue later
from this checkpoint.

Read `docs/deployment/PHASE-DT5-DT8-CONTROLLED-ROLLOUT.md` before the next live
operation. Run its plan mode first. DT5 recovery proof, DT6 content canary, DT7
exact-revision sync and DT8 manual acceptance remain separate fail-closed gates.
The first deployment is internal-only; public DNS/TLS/Ingress is not implied.
