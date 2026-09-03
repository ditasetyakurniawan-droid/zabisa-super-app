# Zabisa Platform

Production-oriented monorepo for Zabisa Mobile, guardian services, internal Backoffice, and platform deployment.

## Local stack

- Go 1.26.7 backend services
- MySQL 8.4 LTS with bounded-context databases
- Next.js Backoffice on `http://localhost:3001`
- API Gateway on `http://localhost:8088`
- NATS JetStream and MinIO development dependencies
- React Native 0.87 mobile application source

Run everything:

```bash
./scripts/run-local.sh
```

The verification script exercises real vertical slices through API, MySQL, transactional outbox, and notification inbox.

## Engineering quality gate

Install the locked Node dependency graph, use Go 1.26.7, and run the same gate
used by CI:

```bash
npm ci --workspaces --include-workspace-root --no-audit --no-fund
make quality
```

The gate produces Sonar-compatible Go and mobile coverage reports. GitHub CI,
SonarQube setup, branch protection, and browser E2E behavior are documented in
`docs/ci/PHASE3.8-QUALITY-GATE.md`.

## Development accounts

All are DEVELOPMENT DATA and use password `ChangeMe123!`:

- `admin@zabisa.local` — SUPER_ADMIN
- `guardian@zabisa.local` — GUARDIAN, linked to demo student
- `ustadz@zabisa.local` — USTADZ
- `teacher@zabisa.local` — GURU_AKADEMIK

Never use these credentials outside local development.

## Mobile Android

Generate native React Native scaffolding once:

```bash
./scripts/bootstrap-mobile-native.sh
npm ci --workspaces --include-workspace-root --no-audit --no-fund
cd apps/mobile
npm run android
```

Android emulator calls the local gateway through `http://10.0.2.2:8088`. iOS simulator uses `http://localhost:8088`.

## Security model

Backoffice uses a server-side BFF. Access and refresh tokens are stored in HttpOnly SameSite cookies and are not exposed to browser JavaScript. Mobile tokens are stored in Keychain/Keystore through `react-native-keychain`. Backend services independently enforce role and object-level access.

## Source of truth

Business configuration, donation accounts, content, programs, kajian, and student data belong to backend databases. Do not hardcode production business data in mobile source.

See `docs/product/FEATURE_MATRIX.md` for implementation status and remaining production integrations.

<!-- ZABISA_MOBILE_PHASE3_DOCS -->
## Mobile development

Mobile developer entry point: `docs/mobile/README.md`.

```bash
npm run mobile:doctor
npm run mobile:device
npm run mobile:e2e:guardian
```

Local physical-device debug builds use ARM64 only through the development script; release ABI behavior is unchanged.

<!-- ZABISA_MOBILE_PHASE32 -->
### Populated Guardian mobile validation

```bash
npm run mobile:seed:guardian
npm run mobile:e2e:guardian:populated
```

The seed command is development-only and refuses non-localhost API targets.
Canonical private notification links include student context and are documented in `docs/api/DEEP_LINKS.md`.

<!-- ZABISA_PHASE33_DEMO_DATA -->
### Full local development demo data

Populate and verify every currently implemented product module with fictitious local data:

```bash
npm run demo:refresh
```

The tooling refuses non-localhost API targets and never writes directly to MySQL. See `docs/mobile/PHASE3_3_DEMO_DATA.md`.

## Immutable image pipeline

Offline-safe image inventory and GitOps-render verification:

```bash
make images-verify
make images-plan
```

CI builds nine SHA-tagged images (eight Go services plus `admin-web`), scans HIGH/CRITICAL findings with Trivy, emits CycloneDX SBOMs, and pushes to Harbor only on `main` after Jenkins credential-based login. The pipeline never creates `:latest`.

## DT Vault integration

The DT deployment reuses the existing Vault Agent Injector. Go workloads use one Kubernetes ServiceAccount/Vault role per bounded context, projected `audience=vault` tokens, TLS through the existing CA, and `*_FILE` runtime secret loading. No production secret value is stored in Git.

Offline validation:

```bash
make vault-verify
```

First-time cluster bootstrap and Vault administrative steps are intentionally separated from repository patching. Follow `docs/deployment/VAULT.md` before enabling ArgoCD sync.

### Vault Agent canary (Hotfix 0.3.3)
After Vault administrative authentication and cluster prerequisites are ready, use `scripts/run-vault-canary.sh` to perform one temporary end-to-end injector test before provisioning production DT secrets. The runner cleans up its temporary Pod, Vault role/policy and KV v2 canary data.

### DT external MySQL
`db-dt` is represented inside `zabisa-app` by a selectorless headless Service and manual EndpointSlice pointing to the Docker Compose host `192.168.100.70:3306`. Stateful services continue to use `MYSQL_HOST=db-dt`.

### db-dt probe portability (Hotfix 0.3.5)
The external MySQL abstraction is unchanged. The runtime proof now tolerates BusyBox `nslookup` returning non-zero during search-suffix attempts, explicitly verifies the `192.168.100.70` A record, and then tests `db-dt:3306`.

### DT DB security boundary (Hotfix 0.3.6)
DT backend runtime uses `APP_MODE=serve`, DML-only DB identities, and client-enforced MySQL TLS with a pinned CA. Schema migrations run as seven separate ArgoCD PreSync Jobs using migration-only ServiceAccounts/Vault roles/KV paths and the same immutable service images. The MySQL CA is external to Git and must be bootstrapped as `zabisa-app/mysql-ca` before first sync. See `docs/deployment/HOTFIX-0.3.6-DB-SECURITY-BOUNDARY.md`.
