# Mobile UX Acceptance Checklist

## Global

- Sky-blue semantic tokens are used instead of screen-level brand hex values.
- Minimum touch targets remain usable on physical Android hardware.
- Text never sits behind the Android system navigation area.
- Loading, empty, error, and success states are visible for API screens.
- Raw backend errors are not displayed to users.

## Authentication

- Login is a root-stack flow without the main bottom navigation.
- Password is masked by default.
- Show/hide password remains accessible by semantic label.
- Development credentials are visible only under `__DEV__`.
- Production sessions remain in Keychain / Android Keystore.

## Guardian

- Linked student identity is clear.
- Tahfidz, grades, attendance, and published reports can all be validated with populated development data.
- Attendance status and report status use Indonesian labels.
- Technical E2E notes are normalized before display.

## Notifications

- Unread count is visible.
- Opening an item marks it read.
- Mark-all-read uses the real notification API.
- Guardian Tahfidz/Academic notifications resolve the linked student.
- New deep links carry student context; legacy links remain supported.
