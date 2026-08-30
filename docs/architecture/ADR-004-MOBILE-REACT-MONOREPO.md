# ADR-004: Isolate Mobile React Resolution in the Monorepo

Status: Accepted

## Context

The workspace contains Admin Web and React Native. Their React versions can differ. Hoisted packages such as TanStack Query may otherwise resolve a second React instance, causing invalid hook calls at runtime.

## Decision

Metro disables hierarchical lookup, searches Mobile node_modules before workspace node_modules, and explicitly maps `react` and `react-native` to Mobile's local packages. Other hoisted dependencies remain usable.

## Consequences

- Mobile and Admin Web can evolve independently.
- Do not introduce a root `overrides.react` solely to fix Mobile.
- `npm run mobile:doctor` must be used after dependency changes.
