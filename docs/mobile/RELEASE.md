# Mobile Release Notes

## Debug development

Use ARM64-only native compilation on the physical phone:

```bash
ZABISA_REBUILD=1 npm run mobile:device
```

This optimization is intentionally passed as a CLI property and does **not** change release ABI coverage.

## Release builds

Release builds must not inherit the local ARM64-only flag. Android release should use the normal configured ABI/App Bundle strategy and production signing credentials from the CI secret store.

Before release:

- generate production runtime API config over HTTPS;
- run lint/typecheck/tests/Sonar quality gate;
- verify no development seed credentials are visible;
- use production keystore, never `debug.keystore`;
- validate Proguard/R8 decision;
- validate push notification credentials and deep links;
- perform Guardian and Donation critical E2E scenarios.
