# Mobile Troubleshooting

## `EADDRINUSE :::8081`

Host port 8081 is already occupied. Zabisa deliberately uses host Metro `8082`; the phone still talks to `8081` through ADB reverse. Use `npm run mobile:device` instead of starting Metro manually on 8081.

## `Invalid hook call` / `useEffect of null`

Usually means multiple React instances. Run:

```bash
npm run mobile:doctor
```

Do not fix this by forcing the Admin Web React version to match Mobile. Mobile's Metro config pins its own React singleton.

## Codegen module missing

Run:

```bash
./scripts/mobile-prepare-native.sh
```

It creates the required monorepo Codegen symlink without duplicating the package.

## Build stalls/crashes during CMake

Use the physical-device ARM64 path:

```bash
ZABISA_REBUILD=1 npm run mobile:device
```

Close emulator/Android Studio and unnecessary browser tabs. Check memory and swap with `free -h && swapon --show`.

## App opens but API data does not load

Check:

```bash
curl http://127.0.0.1:8088/health/live
adb reverse --list
tail -n 150 /tmp/zabisa-metro.log
```

## Password appears blank/invisible

All auth password inputs must use shared `TextField` with an explicit text color and `secureToggle`. Do not create ad-hoc password `TextInput` styling in feature screens.
