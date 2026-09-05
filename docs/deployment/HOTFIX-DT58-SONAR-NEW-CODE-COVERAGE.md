# DT5–DT8 Sonar New Code coverage hotfix

## Failure checkpoint

The Jenkins readiness analysis passed Go and Node execution, analyzed all 72
TypeScript source files and imported both configured LCOV reports. Sonar then
rejected application revision `ab12b8edab44afa56786c7d04ae12bcedc4c7cfb`:

```text
Coverage on New Code: 15.1%
New Lines to cover: 100
Required: 80.0%
```

All other displayed New Code conditions passed: zero bugs, vulnerabilities,
security hotspots and duplication, with maintainability rating A. Readiness
stopped before Trivy, image build, Harbor publication, GitOps publication,
migration or ArgoCD. The Jenkins parent returned to DISABLED.

## Root cause

Coverage import was healthy. The Phase 3.9.1 Nawasena presentation introduced
new executable rendering and interaction branches in shared UI, Home, service
screens and root navigation, while the existing Mobile suite primarily covered
utilities, auth and password visibility. The result was a genuine computed
coverage deficit, not a missing-LCOV condition.

## Correction

The hotfix adds behavioural tests for:

- shared layout, headings, cards, buttons, service tiles and state components;
- public and guardian Home variants;
- all colour-coded Home shortcuts and destination routing;
- kajian/campaign loading, populated, error, retry and empty states;
- donation and kajian list/detail/checkout interactions;
- coloured bottom-tab rendering and guest Account protection.

No production component, API, auth, state, navigation destination or business
transaction is changed. Sonar exclusions, the New Code definition and the 80%
Quality Gate remain unchanged.

Version 1.2 also corrects the local React Native test harness by supplying Safe
Area context mocks, selecting only renderer nodes with callable `onPress`
handlers, and awaiting asynchronous `act` scopes. These are test-only changes.

## Resume boundary

Local lint, typecheck, Jest and LCOV presence must pass before the coverage
hotfix can be committed. GitHub quality must pass before Jenkins is retried.
DT5–DT8 live execution remains blocked until Jenkins readiness, delivery,
Harbor evidence and GitOps read-back all pass.
