# Mobile Testing

## Quality commands

```bash
npm run typecheck --workspace=@zabisa/mobile
npm run lint --workspace=@zabisa/mobile
npm run mobile:e2e:guardian
```

For a full local Tahfidz event chain:

```bash
ZABISA_E2E_MUTATE=1 npm run mobile:e2e:guardian
```

## Guardian acceptance checklist

A Guardian flow is not DONE until all are verified:

- secure login succeeds;
- linked student comes from backend relationship data;
- tahfidz loads independently;
- grades load independently;
- attendance loads independently;
- report state loads independently;
- notification inbox contains child-related messages;
- one failing subsection does not blank all other guardian data;
- session expiry returns the user to a safe re-login state;
- no raw token/password/private student data appears in logs.

## Automated tests

Phase 3 adds the React Native Jest preset, safe API error-mapping tests, and a component test for the password visibility control. `npm test --workspace=@zabisa/mobile` writes genuine LCOV output to `apps/mobile/coverage/lcov.info`, which matches the existing Sonar configuration.

Component and navigation coverage is still intentionally marked as remaining work until those tests are implemented and stable on RN 0.87. Do not inflate coverage with meaningless snapshots.


## Password visibility regression

The password field has a regression test that verifies:

1. password text is masked by default;
2. the show-password control is accessible through a semantic label;
3. pressing the control changes `secureTextEntry` to false;
4. the accessibility label changes to `Sembunyikan password`.

Tests locate interactive controls using accessibility props instead of
React Native implementation component identity. This makes the test less
coupled to internal `Pressable` rendering behavior.
