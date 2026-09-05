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

Expected repository state after DT4.5.6 Harbor alignment installation:

```text
main synchronized with origin/main
clean worktree
DT4.5.6 Jenkins/Sonar/Trivy/Harbor/GitOps source invariants: PASS
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

**DT4.5.6 — Authorized Harbor project and controlled delivery resume ready**

The Multibranch job `zabisa-super-app-v1` exists on the existing Docker Compose
Jenkins and is disabled with no automatic trigger. Readiness build `#6` passed
Sonar Quality Gate and Trivy with publication controls off. Delivery build
`#7` stopped before its first image build because repository-root Jenkins
metadata triggered the dirty-worktree safety gate. No image or manifest was
published by that build.

Build `#10` passed Sonar with 96.2% new-code coverage and built all nine images.
It stopped at the first Trivy image-policy result; Harbor push and GitOps publish
were not reached. DT4.5.4 retains full evidence, evaluates all images and blocks
only fixable HIGH/CRITICAL findings.

Next controlled execution:

**DT4.5.6 — Build, scan, Harbor push and GitOps publish**

Use `scripts/run-zabisa-jenkins-delivery.sh --resume-after-readiness` with
`DT43_READINESS_BUILD=6`. The runner verifies build `#6` and performs only one
new explicitly enabled build/scan/push/publish run. Migration, Kubernetes
application and ArgoCD sync remain separate approvals.
