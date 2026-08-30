# Zabisa Mobile Development

This is the entry point for engineers working on `apps/mobile`.

## Current baseline

- React Native 0.87.0, TypeScript, Hermes, New Architecture.
- React Navigation 7, TanStack Query 5, Zustand, Android Keystore/Keychain.
- Android physical-device local development is the preferred low-memory workflow.
- Local API gateway: host `8088`; Metro: host `8082`; device Metro port remains `8081` through ADB reverse.
- Production-like environments must use HTTPS and must not embed credentials in mobile code.

## One-command workflow

```bash
npm run mobile:doctor
npm run mobile:device
```

`mobile:device` starts the minimum backend if needed, prepares monorepo native dependencies, configures ADB reverse, starts/reuses Metro, installs an APK when necessary, and opens the app.

To force a native ARM64 rebuild:

```bash
ZABISA_REBUILD=1 npm run mobile:device
```

To reset Metro cache:

```bash
ZABISA_RESET_METRO=1 npm run mobile:device
```

## Guardian vertical slice

Read-only API verification:

```bash
npm run mobile:e2e:guardian
```

Full local mutation test (`TahfidzEntryCreated -> outbox/event -> guardian notification`):

```bash
ZABISA_E2E_MUTATE=1 npm run mobile:e2e:guardian
```

A passing API script does not replace physical-device UI validation.

## Documents

- [Architecture](ARCHITECTURE.md)
- [Local development](LOCAL_DEVELOPMENT.md)
- [Android physical device](ANDROID_PHYSICAL_DEVICE.md)
- [Environments](ENVIRONMENTS.md)
- [Testing](TESTING.md)
- [Troubleshooting](TROUBLESHOOTING.md)
- [Release](RELEASE.md)
