# Mobile Debugging Runbook

1. `npm run mobile:doctor`
2. Verify API `curl -fsS http://127.0.0.1:8088/health/live`
3. Verify device `adb devices`
4. Verify reverse mappings `adb reverse --list`
5. Verify Metro `curl -fsS http://127.0.0.1:8082/status`
6. Inspect Metro log `tail -n 150 /tmp/zabisa-metro.log`
7. For API Guardian issues run `npm run mobile:e2e:guardian`
8. Only rebuild native Android if the issue is native or APK installation related.

Never start with a clean/rebuild for a normal TypeScript/UI defect. It wastes time and increases workstation memory pressure.
