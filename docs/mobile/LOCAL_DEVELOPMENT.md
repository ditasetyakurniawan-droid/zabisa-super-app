# Local Mobile Development

## Prerequisites

- Node.js >= 22
- Java 21 (current local build baseline)
- Android SDK and platform tools
- NDK `27.1.12297006`
- Docker + Compose
- Authorized Android device with USB debugging

Check everything with:

```bash
npm run mobile:doctor
```

## Recommended daily workflow

1. Connect the Android phone and accept USB debugging authorization.
2. Keep Android Studio/emulator closed unless needed. Physical device saves substantial RAM.
3. Run:

```bash
npm run mobile:device
```

JavaScript/TypeScript UI changes are delivered by Metro and normally do not require an APK rebuild.

Use `ZABISA_REBUILD=1` only after native dependency/config changes or when the APK is missing.

## Memory profile

The local native build uses:

- `--no-daemon`
- max 2 Gradle workers by default
- `-PreactNativeArchitectures=arm64-v8a`
- Gradle heap configured in `android/gradle.properties`

Override workers only if the workstation has sufficient memory:

```bash
ZABISA_GRADLE_WORKERS=3 ZABISA_REBUILD=1 npm run mobile:device
```
