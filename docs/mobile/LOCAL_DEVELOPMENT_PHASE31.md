# Phase 3.1 Daily Mobile Workflow

Normal JavaScript/UI development:

```bash
npm run mobile:device
```

Run all mobile quality gates:

```bash
npm run mobile:quality
```

After Android native theme/dependency changes only:

```bash
ZABISA_REBUILD=1 npm run mobile:device
```

Do not use `adb shell pm clear` as a standard workflow. Some OEM Android builds deny `CLEAR_APP_USER_DATA`. Use in-app logout for session reset, or device Settings > Apps > Zabisa > Storage > Clear data only when a true clean-state test is required.
