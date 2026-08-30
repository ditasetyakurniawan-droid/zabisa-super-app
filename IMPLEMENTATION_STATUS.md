# Implementation status

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
