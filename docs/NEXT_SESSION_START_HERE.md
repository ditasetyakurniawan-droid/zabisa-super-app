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

Expected repository state after DT4.5.7 and Phase 3.9.1 acceptance:

```text
main synchronized with origin/main
clean worktree
DT4.5.7 immutable delivery: COMPLETE
Phase 3.9.1 source/mobile/Backoffice gates: PASS
Nawasena physical Android acceptance: PASS at f1ba188
```

## 2. Read in this order

1. `docs/deployment/CURRENT-STATE-AND-ROADMAP.md`
2. `docs/PROJECT_STATE.md`
3. `docs/runbook/JENKINS_DELIVERY.md`
4. `docs/deployment/PHASE-DT4-IMMUTABLE-IMAGES.md`
5. `docs/KNOWN_LIMITATIONS.md`
6. the domain document relevant to the next task.

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

Current source checkpoint:

**DT5–DT8 — controlled migration and internal rollout**

Jenkins build `#14` completed successfully for application revision
`e1af81dc96d5dc59876f090614e68dc48a32c59f`. Harbor has nine verified images;
GitOps commit `96cef84` has 16 immutable references across 12 manifests. The
Jenkins parent job is disabled. Migration and ArgoCD sync have not run.

Phase 3.9.1 passed 25 mobile tests, Guardian API E2E, Backoffice source/runtime,
GitHub Engineering Quality Gate and physical Android installation/opening at
`f1ba18854af2a2a965090af41eb8bfc40a637cb1`. UI development may continue later
from this checkpoint.

Read `docs/deployment/PHASE-DT5-DT8-CONTROLLED-ROLLOUT.md` before the next live
operation. Run its plan mode first. DT5 recovery proof, DT6 content canary, DT7
exact-revision sync and DT8 manual acceptance remain separate fail-closed gates.
The first deployment is internal-only; public DNS/TLS/Ingress is not implied.
