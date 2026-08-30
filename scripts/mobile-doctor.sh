#!/usr/bin/env bash
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
fail=0
check(){ if command -v "$1" >/dev/null 2>&1; then printf 'OK   %-18s %s\n' "$1" "$(command -v "$1")"; else printf 'FAIL %-18s missing\n' "$1"; fail=1; fi; }
echo '=== Zabisa Mobile Doctor ==='
for c in node npm java docker curl python3; do check "$c"; done
ANDROID_HOME=${ANDROID_HOME:-$HOME/Android/Sdk}
ADB=${ADB:-$ANDROID_HOME/platform-tools/adb}
if [[ -x "$ADB" ]]; then echo "OK   adb                $ADB"; else echo "FAIL adb                $ADB not found"; fail=1; fi
printf '\n=== Versions ===\n'
node --version 2>/dev/null || true
npm --version 2>/dev/null || true
java -version 2>&1 | head -2 || true
docker --version 2>/dev/null || true
printf '\n=== Memory ===\n'; free -h || true; swapon --show || true
printf '\n=== Device ===\n'
if [[ -x "$ADB" ]]; then "$ADB" start-server >/dev/null 2>&1 || true; "$ADB" devices; "$ADB" reverse --list 2>/dev/null || true; fi
printf '\n=== Local Services ===\n'
if curl -fsS http://127.0.0.1:8088/health/live >/dev/null 2>&1; then echo 'OK   API :8088'; else echo 'WARN API :8088 is not healthy'; fi
if curl -fsS http://127.0.0.1:8082/status 2>/dev/null | grep -q 'packager-status:running'; then echo 'OK   Metro :8082'; else echo 'INFO Metro :8082 is not running'; fi
printf '\n=== React Resolution ===\n'
node <<'NODE'
const path=require('path');
const root=process.cwd(), mobile=path.join(root,'apps/mobile');
for(const name of ['react','react-native','@tanstack/react-query','@react-native/metro-config']){
  for(const [label,base] of [['mobile',mobile],['root',root]]){
    try{const f=require.resolve(`${name}/package.json`,{paths:[base]});const p=require(f);console.log(`${name}\t${label}\t${p.version}\t${f}`)}catch{console.log(`${name}\t${label}\tNOT_FOUND`)}
  }
}
NODE
printf '\n=== Native Prerequisites ===\n'
if [[ -d "$ANDROID_HOME/ndk/27.1.12297006" ]]; then du -sh "$ANDROID_HOME/ndk/27.1.12297006"; else echo 'WARN NDK 27.1.12297006 missing'; fi
[[ $fail -eq 0 ]] || exit 1
