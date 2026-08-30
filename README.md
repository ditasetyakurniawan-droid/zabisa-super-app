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
npm install
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
