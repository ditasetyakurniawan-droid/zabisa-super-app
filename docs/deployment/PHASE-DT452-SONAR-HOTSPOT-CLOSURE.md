# DT4.5.2 — Sonar Hotspot Closure

## Evidence

Jenkins delivery build `#8` completed source tests and private Sonar analysis,
then stopped at the blocking Quality Gate. The only failed condition was
`Security Hotspots Reviewed on New Code`: ten hotspots remained `TO_REVIEW`.

The source audit identified exactly:

- eight `docker:S6470` findings caused by `go.sum*` wildcard copies;
- one `typescript:S2245` finding caused by `Math.random()` in the donation
  idempotency key;
- one `typescript:S5332` finding caused by the Backoffice hard-coded clear-text
  backend default.

## Source corrections

- All eight Go images copy `go.mod` and `go.sum` explicitly.
- Donation idempotency keys use timestamp, campaign identity and a monotonic
  process sequence. They are collision-control identifiers, not credentials.
- Backoffice requires `BACKEND_INTERNAL_URL`, accepts HTTPS for external hosts,
  and permits clear-text compatibility only for the reviewed in-cluster/local
  host allowlist. Kubernetes NetworkPolicy remains the transport boundary for
  the current internal API Gateway connection.
- The standalone admin Sonar tsconfig includes its Playwright config and E2E
  source, bringing the intended TypeScript analysis set from 68/70 to 70/70.

No hotspot is marked `Safe`, no Sonar rule is disabled and the Quality Gate is
not weakened. `scripts/verify-dt452-sonar-hotspots.sh` prevents recurrence.

## Controlled continuation

After the source commit and GitHub gate pass, reuse readiness build `#6` and
start exactly one parameterized Jenkins delivery build. On success it builds,
scans, creates SBOM evidence, pushes nine immutable images to Harbor and
publishes the rendered desired state to `zabisa-super-app-gitops`.

Database migration and Argo CD sync remain outside this step.
