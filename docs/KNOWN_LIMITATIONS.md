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

GitHub Actions is the authoritative source gate and Jenkins build `#14` proved
the private Sonar/Trivy/Harbor/GitOps delivery chain. Cluster image pulling,
database migration, deployment and ArgoCD reconciliation are still unproven.

## Sonar/security scanning

Private Sonar Quality Gate, secret hygiene, Trivy policy, nine SBOMs and Harbor
digest evidence passed in build `#14`. This is not a claim that future source or
new dependencies are automatically risk-free; every revision must pass again.

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
