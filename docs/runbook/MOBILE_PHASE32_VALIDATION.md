# Phase 3.2 Physical Device Validation

Run in this order:

```bash
npm run mobile:quality
npm run mobile:seed:guardian
npm run mobile:e2e:guardian:populated
ZABISA_REBUILD=1 npm run mobile:device
```

On OPPO validate:

1. Account while logged out opens standalone Login with no bottom tabs.
2. Password bullets and show/hide control are clearly visible.
3. Home greeting does not show generic `Wali` as if it were a personal name.
4. Guardian detail contains at least one grade, three attendance rows, and one published report after the development seed.
5. `Automated E2E verification` is not rendered verbatim.
6. Opening a notification clears its unread visual state.
7. `Tandai semua dibaca` clears remaining unread items.
8. Android bottom navigation area does not obscure Zabisa content.

If the OEM still forces a system navigation scrim, record it as device-specific system UI behavior rather than hiding application content behind it.
