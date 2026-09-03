# Phase 3.8 Changeset — Engineering Quality Foundation

Status: source implementation complete; phase closes only after the real CI and SonarQube quality gates pass.

## Review order

1. `.github/workflows/ci.yml` — pull-request quality gate and isolated browser E2E.
2. `scripts/quality-gate.sh` and `scripts/go-quality.sh` — canonical local/CI checks.
3. `sonar-project.properties` — source, test, and coverage report mapping.
4. `services/api-gateway/{main,handler,routes,access}.go` — gateway responsibility split.
5. `apps/mobile/src/navigation/types.ts` and the feature screens — typed navigation and API DTOs.
6. `docs/ci/PHASE3.8-QUALITY-GATE.md` — operator setup and branch-protection contract.

## Added

- `.github/dependabot.yml`
- `.github/workflows/ci.yml`
- `docs/ci/PHASE3.8-CHANGESET.md`
- `docs/ci/PHASE3.8-QUALITY-GATE.md`
- `docs/ci/phase3.8-files.txt`
- `scripts/go-quality.sh`
- `scripts/npm-audit-gate.sh`
- `scripts/quality-gate.sh`
- `scripts/verify-npm-audit.mjs`
- `scripts/verify-quality-gate.sh`
- `scripts/verify-secret-hygiene.sh`
- `services/api-gateway/access.go`
- `services/api-gateway/handler.go`
- `services/api-gateway/routes.go`

## Modified

### Build, CI, and quality

- `Jenkinsfile`
- `Makefile`
- `package.json`
- `scripts/preflight-offline.sh`
- `scripts/run-local.sh`
- `sonar-project.properties`

The dependency gate keeps exact, expiring exceptions for two unpatched
transitive `image-size` advisories. It does not permit new high/critical
advisories and does not use `npm audit fix --force`.

### API Gateway

- `services/api-gateway/main.go`
- `services/api-gateway/main_test.go`

### Mobile typing and readability

- `apps/mobile/src/navigation/RootNavigator.tsx`
- `apps/mobile/src/navigation/types.ts`
- `apps/mobile/src/types/domain.ts`
- `apps/mobile/src/features/account/AccountScreen.tsx`
- `apps/mobile/src/features/auth/LoginScreen.tsx`
- `apps/mobile/src/features/content/ContentDetailScreen.tsx`
- `apps/mobile/src/features/content/ContentListScreen.tsx`
- `apps/mobile/src/features/donation/CampaignDetailScreen.tsx`
- `apps/mobile/src/features/donation/DonationCheckoutScreen.tsx`
- `apps/mobile/src/features/donation/DonationScreen.tsx`
- `apps/mobile/src/features/guardian/GuardianOverviewScreen.tsx`
- `apps/mobile/src/features/guardian/GuardianStudentScreen.tsx`
- `apps/mobile/src/features/home/HomeScreen.tsx`
- `apps/mobile/src/features/kajian/KajianDetailScreen.tsx`
- `apps/mobile/src/features/kajian/KajianScreen.tsx`
- `apps/mobile/src/features/notifications/NotificationsScreen.tsx`

### Documentation and handoff

- `README.md`
- `docs/DEVELOPMENT_ROADMAP.md`
- `docs/NEXT_SESSION_START_HERE.md`
- `docs/PHASE_HISTORY.md`
- `docs/TESTING_QUALITY.md`

## Explicitly unchanged

- MySQL schema and migrations
- external DT MySQL endpoint and DNS abstraction
- Vault policies, identities, and injected secret paths
- Kubernetes database runtime/migrator boundary
- API business contracts
- the three local operator-owned MySQL/Vault provisioning files documented in the Phase 3.8 quality-gate guide

No file is deleted by this changeset.
