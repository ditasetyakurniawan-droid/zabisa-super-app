# Implementation status

## Current locked delivery checkpoint — 2026-09-06

- Application/image revision:
  `eee3284a6989857b6d4332f01d453763ccaf71b2`.
- GitHub quality gate, Jenkins readiness `#18`, private Sonar 75% gate and
  Jenkins delivery `#19`: PASS.
- Nine immutable Harbor images and digest references: VERIFIED.
- GitOps `4fbc8b5db597cbdf73199f8f927eb0ac2cc544c9`: 16 image references across
  12 manifests.
- Jenkins parent: DISABLED.
- Kubernetes deployment, MySQL migration and ArgoCD sync: NOT RUN.
- Developer handoff and two-stage local testing:
  `docs/DEVELOPER_GUIDE_ID.md`.

## Implemented in this repository
- Go microservice monorepo: API gateway, identity, content, student, tahfidz, academic, donation, notification.
- MySQL 8.4 LTS strategy with one logical database per bounded context.
- Versioned transactional migrations and development bootstrap.
- Authentication with Argon2id, short-lived access tokens, rotating refresh tokens and session revocation.
- Public kajian/content APIs and admin kajian creation.
- Guardian/student link request + approval, linked-student query and attendance.
- Tahfidz entry persistence and guardian-facing reads through BFF object-level checks.
- Configurable academic subjects and published grades.
- Donation campaign, configurable payment accounts, idempotent donation creation, payment proof metadata, server-side manual verification and transactional campaign progress update.
- Notification inbox, device-token registration, internal domain-event ingestion, guardian resolution and transactional outbox retry worker for kajian/tahfidz/grade events.
- React Native TypeScript mobile app wired to real APIs; secure token storage via Keychain/Keystore library.
- Next.js backoffice wired to real APIs for core staff operations.
- Docker Compose, distroless/non-root service images, Jenkins, SonarQube config, Harbor image build/Trivy scan scripts, Kubernetes restricted workloads, NetworkPolicy baseline, ArgoCD and Vault documentation.
- OpenAPI starter contract, architecture, C4, PRD, threat model, backup and incident runbooks.

## External-production integrations intentionally not falsely marked complete
The repository does not claim successful production FCM/APNs delivery or third-party payment-gateway settlement without credentials. Those integrations require credentials/provider choices from Vault and must be verified in the target DT environment. The local/manual donation flow is real server-side behavior; no random/fake payment success is used.

## Validation performed in this environment
- `gofmt` completed on Go source.
- Standard-library platform packages compile and tests pass: router, httpx, config, server.
- Full Go dependency download/compile could not execute because this sandbox cannot resolve `proxy.golang.org`.
- Docker is not installed in this sandbox, so Compose/image runtime validation must run in Jenkins/developer infrastructure.

## Infrastructure hotfix checkpoint — 2026-08-31
- Hotfix 0.1: repository hygiene hardened; Android/TypeScript/test/Python backup caches are excluded from Git and Docker contexts. `node_modules` remains generated-only while `package-lock.json` remains authoritative for `npm ci`.
- Hotfix 0.2: Kubernetes target namespace changed to `zabisa-app`; NetworkPolicy remains default-deny with explicit DNS, namespace-local backend, existing MySQL (`192.168.100.70:3306`), and labeled-ingress-controller access only.
- Vault Agent Injector remains the selected DT secret mechanism; exact annotations/egress are intentionally deferred until the existing Vault topology/configuration is inspected rather than guessed.

## Hotfix 0.2.1 — Offline Preflight Gate

- Repository/deployment preflight no longer depends on Kubernetes API availability.
- Cluster validation is opt-in via `ZABISA_VALIDATE_CLUSTER=1` and remains required before deployment.
- Added offline checks for generated tracked files, namespace/NetworkPolicy invariants, basic secret hygiene, JSON/shell/YAML syntax, and Docker Compose parsing where local tools are available.
- Full mode additionally runs local TypeScript lint/typecheck and Go tests without automatic Go toolchain download.

## Hotfix 0.2.2 — Deterministic Node CI / Build

- Node CI/bootstrap paths now use `npm ci` and treat `package-lock.json` as authoritative.
- Admin Web Docker build is workspace-scoped and copies the root lockfile before installing dependencies.
- Added an offline lockfile/workspace synchronization verifier and wired it into offline preflight.
- No Kubernetes/cluster connectivity is required for this hotfix.
- Harbor/admin image pipeline completeness remains intentionally deferred to Hotfix 0.2.3.
- Offline validation passed for synchronized lockfile/workspaces; a deliberately drifted workspace manifest was correctly rejected; admin-only `npm ci --dry-run` accepted the minimal Docker dependency context without React Native dependencies.
- Full package download/build was not executed in this sandbox because external npm access is unavailable; base-image digest pinning is not claimed by this hotfix.

## Hotfix 0.2.3 — Immutable Image Pipeline Baseline

- Image inventory is explicit and complete: eight Go services plus `admin-web` (9 total).
- Image tags are validated Git SHAs; production build/deployment paths reject `:latest`.
- Jenkins builds/scans every image, archives CycloneDX SBOMs, and pushes SHA-tagged images to Harbor on `main` only after Jenkins credential-based login.
- `admin-web` now has a restricted Kubernetes Deployment/Service/PDB and NetworkPolicy allowing only ingress-controller -> admin and admin -> API gateway traffic.
- `scripts/update-gitops.sh` now performs a real immutable manifest render instead of an echo-only placeholder; it does not falsely claim GitOps repository publication.
- Offline image/GitOps invariants are wired into repository preflight and require no cluster connectivity.
- Base-image digest pinning, Harbor image-pull auth and real GitOps repository publication remain explicit pre-production follow-ups because their existing infrastructure details have not yet been inspected.

## Hotfix 0.3 — Existing Vault Agent Injector Integration

- DT Vault topology was discovered from working cluster workloads rather than guessed: Vault Agent Injector `1.7.5`, `vault.vault.svc`, TLS CA secret `vault-ca`, Kubernetes auth default path, projected token audience `vault` / TTL 3600, and role-per-workload behavior.
- Eight Go workloads now use dedicated Kubernetes ServiceAccounts and Vault roles/policies. Automatic default SA-token mounting remains disabled; a narrowly scoped projected `vault-token` is used only by Vault Agent auto-auth.
- Vault renders JWT signing material, the internal service key and per-context MySQL credentials as `0400` files. Go config supports `*_FILE`, gives it precedence over direct environment values, and fails startup on missing/unreadable secret files.
- Distroless Go containers explicitly run UID/GID 65532 and Vault Agent uses `agent-run-as-same-user`, avoiding shell wrappers and avoiding group/world-readable secrets.
- Calico NetworkPolicy now explicitly permits backend -> Vault TCP/8200, restricts MySQL egress to database-owning services, and targets the discovered ingress-nginx labels directly without mutating unrelated namespaces.
- `admin-web` has no Vault injection because it currently has no runtime secret requirement.
- First deployment is fail-safe and prerequisite-driven: Vault KV values + policies/roles, namespace/ServiceAccounts/NetworkPolicies, CA-only `vault-ca`, then ArgoCD application sync. The ArgoCD Application no longer auto-creates the namespace.
- Cluster mutation is not performed by the repository hotfix itself. Vault administrative authentication and real secret values remain explicit operator actions.

### Hotfix 0.3.1 — Explicit kubectl selection
- Fixed cluster scripts to honor `KUBECTL=/path/to/kubectl` instead of always resolving literal `kubectl` from PATH.
- Added offline verifier `scripts/verify-kubectl-override.sh`.
- No cluster mutation is performed by the hotfix application script.

## Hotfix 0.3.2 — kubectl JSONPath portability

- Replaced unsupported Go-template-style `$k,$v :=` kubectl JSONPath Secret-key inspection with portable JSON + Python inspection.
- `vault-ca` bootstrap validates exactly one non-empty `ca.crt` key without printing secret bytes.
- Partial prerequisite bootstrap is recoverable by idempotent rerun.

## Hotfix 0.3.3 — Vault Agent canary
- Added an explicit temporary end-to-end Vault Agent Injector canary.
- Canary uses the existing `zabisa-api-gateway` ServiceAccount but a separate temporary Vault role/policy and KV path.
- Canary uses init-only injection, TLS `vault-ca`, projected audience=`vault` token, and validates a `0400` rendered file.
- Canary refuses to overwrite pre-existing names and attempts full cleanup including KV v2 metadata/versions.
- Production credentials and application Deployments remain untouched by the hotfix apply step.

## Hotfix 0.3.4 — External MySQL DNS abstraction
- Direct cluster probe proved `192.168.100.70:3306` reachable from a MySQL-authorized Zabisa pod.
- `db-dt` DNS was NXDOMAIN before this hotfix.
- Added selectorless headless `Service/zabisa-app/db-dt` + manual `EndpointSlice` to `192.168.100.70:3306`.
- Existing Calico egress remains authoritative; no DB credential added.

## Hotfix 0.3.5 — BusyBox db-dt probe portability
- Cluster evidence confirmed `db-dt.zabisa-app.svc.cluster.local` resolves to `192.168.100.70`.
- Fixed the runtime probe so BusyBox `nslookup` search-suffix NXDOMAIN exit status does not abort before the actual TCP check.
- DNS success is now asserted from returned A-record output, then `db-dt:3306` is tested directly.
- Service/EndpointSlice/NetworkPolicy topology is unchanged.

## Hotfix 0.3.6 — DB TLS + runtime/migrator identity split
- DT DB clients fail closed if TLS is disabled; runtime and migration Jobs use pinned-CA `verify-ca` with TLS 1.2+.
- Seven runtime Deployments use `APP_MODE=serve` and no longer execute embedded schema migrations at startup.
- Seven ArgoCD PreSync migration Jobs reuse the immutable service images with `APP_MODE=migrate` and exit after migration completion.
- Seven migration-only Kubernetes ServiceAccounts, Vault policies/roles and KV paths are isolated from long-lived runtime identities; migration Jobs receive no JWT/internal-service secrets.
- MySQL CA material remains external to Git and is bootstrapped as `zabisa-app/mysql-ca`.
- Immutable image rendering now handles 9 built images referenced 16 times across runtime + migration manifests.
- Actual MySQL account/database creation, MySQL CA bootstrap, migration Vault role creation and KV values remain explicit operator actions; no DB/Vault secret mutation is performed by the repository apply script.
