# Zabisa Mobile Development

This is the entry point for engineers working on `apps/mobile`.

## Current baseline

- React Native 0.87.0, TypeScript, Hermes, New Architecture.
- React Navigation 7, TanStack Query 5, Zustand, Android Keystore/Keychain.
- Android physical-device local development is the preferred low-memory workflow.
- Local API gateway: host `8088`; Metro: host `8082`; device Metro port remains `8081` through ADB reverse.
- Production-like environments must use HTTPS and must not embed credentials in mobile code.
- Phase 3.9 uses the Sakinah emerald/ivory/gold presentation system. The change
  is UI-only; API, state, authentication, validation and business flows remain
  unchanged.
- DT4.5.7 delivery is complete at application revision
  `e1af81dc96d5dc59876f090614e68dc48a32c59f`; migration and ArgoCD sync have
  not run.

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
- [Sakinah design system](DESIGN_SYSTEM.md)
- [Phase 3.9 UI/UX redesign](PHASE3_9_UI_UX_REDESIGN.md)
- [Troubleshooting](TROUBLESHOOTING.md)
- [Release](RELEASE.md)
