# Admin Web Runtime

Zabisa Backoffice uses Next.js standalone output in its production container.

## Runtime command

The container executes the generated standalone `server.js`. It must not use
`next start` when `output: "standalone"` is enabled.

## Health

The container healthcheck probes `/login`. Deployment tooling should not route
traffic to a new Backoffice instance until the instance is healthy.

## Authentication smoke contract

The Backoffice runtime verifier sends only the fields defined by `LoginRequest`:

- `email`
- `password`

Do not add diagnostic-only fields to this request unless the API contract is
formally extended and documented.

## Navigation smoke

`scripts/verify-admin-runtime.sh` authenticates through the Backoffice BFF and
repeatedly requests protected routes including `/access`, `/dashboard`, and
`/audit` while preserving the session cookie.

## Production deployment

Local Docker Compose has a single Backoffice replica, so replacing that
container can briefly interrupt an already-open browser tab. Production should
use immutable images, readiness/health checks, a reverse proxy or load
balancer, and rolling or blue/green deployment with sufficient replicas when
zero-downtime Backoffice navigation is required.
