# Known Limitations and Non-Claims

Do not allow future work to accidentally reinterpret this baseline as complete
production launch readiness.

## External integrations

### Push

Production FCM/APNs credentials and final delivery-provider behavior are not
complete.

### Payment

Manual/local Donation/payment lifecycle is functional. Production external
payment-provider settlement/webhooks are not claimed complete.

## Mobile automated coverage

The mobile suite passes, but overall coverage is still low and many screen
components lack direct unit/integration coverage.

## iOS

Source/configuration exists, but final iOS native build, signing and release
have not been validated on macOS/Xcode.

## CI/CD

The repository has strong local scripts but GitHub CI/CD has not yet been
established as the authoritative gate.

## Sonar/security scanning

Sonar configuration exists, but final GitHub quality-gate enforcement,
dependency classification, SBOM/container scanning and SAST/secret scanning
remain future work.

## Observability

Request/trace correlation and audit are present. Full production
OpenTelemetry/metrics/log aggregation/SLO/alerting is not complete.

## Production infrastructure

No claim is made yet for:

- HA deployment;
- rolling production rollout;
- managed secrets;
- TLS/domain ingress;
- disaster recovery;
- production backup/restore drill;
- autoscaling;
- production database topology.

## Dynamic permissions

The current permission matrix is code-defined. If permission definitions become
runtime-mutable later, permission mutations must use the same strict audit and
session-revocation discipline as role mutations.

## Test data growth

Repeated development regressions create/deactivate fixtures and increase audit
history. Tests must remain robust to ordering and history size.
