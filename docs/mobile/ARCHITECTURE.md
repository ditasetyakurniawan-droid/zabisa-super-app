# Mobile Architecture

## Principles

The app uses feature-first structure. `src/App.tsx` is only an entry re-export and `src/app/App.tsx` only composes providers. Product logic belongs in feature modules.

```text
src/
  app/
  api/
  assets/icons/
  components/
  config/
  features/
    account/
    content/
    donation/
    guardian/
    home/
    kajian/
    notifications/
  navigation/
  store/
  theme/
  types/
```

## Data flow

```text
Screen -> TanStack Query / Zustand -> api/client.ts -> API Gateway -> bounded-context service -> MySQL
```

Private student data is never provided by local JSON. The backend remains the authorization boundary.

## Authentication

- Session is stored through `react-native-keychain`, backed by Android Keystore / iOS Keychain.
- Access token is attached by the API client.
- A `401` may trigger one refresh attempt.
- Failed refresh clears the local session.
- Passwords/tokens must never be logged.

## React monorepo isolation

Admin Web and Mobile may require different React versions. Do not force a root-wide React version. `metro.config.js` explicitly pins Mobile's `react` and `react-native` resolution to `apps/mobile/node_modules` while allowing hoisted non-React dependencies from the workspace root.

This prevents the classic `Invalid hook call` / `useEffect of null` error caused by two React instances.

## UI system

`theme/tokens.ts` is the source of color, spacing, radius and typography tokens. Shared components are in `components/UI.tsx`. Icons are local monochrome PNG assets tinted by React Native, so no icon font/native font-linking is required.

Every API-backed screen should implement at least loading, success, empty and error states. Offline/network errors are converted to user-facing messages instead of raw backend errors.
