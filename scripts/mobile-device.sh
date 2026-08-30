#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT"
ANDROID_HOME=${ANDROID_HOME:-$HOME/Android/Sdk}; ADB=${ADB:-$ANDROID_HOME/platform-tools/adb}; METRO_PORT=${ZABISA_METRO_PORT:-8082}; API_PORT=${ZABISA_API_PORT:-8088}; PACKAGE=${ZABISA_ANDROID_PACKAGE:-id.or.subulussalam.zabisa}; APK="$ROOT/apps/mobile/android/app/build/outputs/apk/debug/app-debug.apk"; WORKERS=${ZABISA_GRADLE_WORKERS:-2}
export ANDROID_HOME PATH="$ANDROID_HOME/platform-tools:$PATH"
[[ -x "$ADB" ]] || { echo "adb not found: $ADB" >&2; exit 2; }
"$ROOT/scripts/mobile-env.sh"; "$ROOT/scripts/mobile-prepare-native.sh"
if ! curl -fsS "http://127.0.0.1:$API_PORT/health/live" >/dev/null 2>&1; then
  echo 'Starting minimum local Zabisa backend...'; docker compose up -d mysql nats identity content student tahfidz academic donation notification api-gateway
  for _ in $(seq 1 45); do curl -fsS "http://127.0.0.1:$API_PORT/health/live" >/dev/null 2>&1 && break; sleep 2; done
fi
curl -fsS "http://127.0.0.1:$API_PORT/health/live" >/dev/null || { echo "API gateway not healthy on :$API_PORT" >&2; exit 1; }
"$ADB" start-server >/dev/null
DEVICE_COUNT=0
for attempt in $(seq 1 8); do
  DEVICE_COUNT=$("$ADB" devices | awk 'NR>1 && $2=="device"{n++} END{print n+0}')
  [[ "$DEVICE_COUNT" -ge 1 ]] && break
  [[ "$attempt" == 1 ]] && echo 'Waiting for an authorized Android device...'
  sleep 2
done
if [[ "$DEVICE_COUNT" -lt 1 ]]; then
  echo 'No authorized Android device found. The npm child process will stop, but your interactive terminal remains open.' >&2
  echo 'Unlock OPPO, enable USB debugging, choose File Transfer, reconnect USB, and approve the RSA prompt.' >&2
  "$ADB" devices -l
  exit 1
fi
"$ADB" devices -l
"$ADB" reverse --remove tcp:8081 >/dev/null 2>&1 || true; "$ADB" reverse tcp:8081 tcp:"$METRO_PORT" >/dev/null; "$ADB" reverse tcp:"$API_PORT" tcp:"$API_PORT" >/dev/null
if ! curl -fsS "http://127.0.0.1:$METRO_PORT/status" 2>/dev/null | grep -q 'packager-status:running'; then
  ss -ltn 2>/dev/null | grep -q ":$METRO_PORT " && { echo "Port $METRO_PORT occupied by non-Metro process" >&2; exit 1; }
  echo "Starting Metro on :$METRO_PORT ..."; rm -f /tmp/zabisa-metro.log; nohup npm start --workspace=@zabisa/mobile -- --port "$METRO_PORT" ${ZABISA_RESET_METRO:+--reset-cache} >/tmp/zabisa-metro.log 2>&1 & echo $! >/tmp/zabisa-metro.pid
  for _ in $(seq 1 30); do curl -fsS "http://127.0.0.1:$METRO_PORT/status" >/dev/null 2>&1 && break; sleep 2; done
  curl -fsS "http://127.0.0.1:$METRO_PORT/status" >/dev/null || { tail -100 /tmp/zabisa-metro.log; exit 1; }
fi
INSTALLED=0; "$ADB" shell pm path "$PACKAGE" >/dev/null 2>&1 && INSTALLED=1
if [[ ${ZABISA_REBUILD:-0} == 1 || ! -f "$APK" ]]; then echo 'Building ARM64 debug APK...'; (cd apps/mobile/android && ./gradlew app:assembleDebug -PreactNativeArchitectures=arm64-v8a --no-daemon --max-workers="$WORKERS" --console=plain); INSTALLED=0; fi
if [[ "$INSTALLED" == 0 ]]; then [[ -f "$APK" ]] || { echo "APK not found: $APK" >&2; exit 1; }; "$ADB" install -r "$APK"; fi
"$ADB" shell am force-stop "$PACKAGE" >/dev/null 2>&1 || true; sleep 1; "$ADB" shell monkey -p "$PACKAGE" -c android.intent.category.LAUNCHER 1 >/dev/null
echo "READY: $PACKAGE | Metro $METRO_PORT | API $API_PORT | ARM64 debug"; echo 'No pm clear is used because some OEM builds (including OPPO) block CLEAR_APP_USER_DATA over adb.'
