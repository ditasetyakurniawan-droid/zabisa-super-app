# Android Physical Device

Physical Android is the default development target for this workstation.

## Port mapping

```text
Phone 127.0.0.1:8081 -> ADB reverse -> Host Metro :8082
Phone 127.0.0.1:8088 -> ADB reverse -> Host API   :8088
```

The app can therefore use `http://127.0.0.1:8088` in the generated **local** runtime config without exposing a LAN IP.

## Manual commands

```bash
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$ANDROID_HOME/platform-tools:$PATH"
adb devices
adb reverse tcp:8081 tcp:8082
adb reverse tcp:8088 tcp:8088
```

If the cable is reconnected, re-run `npm run mobile:device`; ADB reverse mappings may disappear.

## OPPO / ColorOS

If installation is blocked, verify Developer Options, USB debugging and any `Install via USB` / security authorization setting exposed by the device.
