# Hotfix 0.2.2 — Deterministic Node CI / Build

## Goal

Make Node dependency installation deterministic and lockfile-authoritative without requiring Kubernetes access.

## Changes

- Jenkins Node quality stage uses `npm ci` rather than `npm install`.
- Admin Web Docker build copies `package-lock.json` before dependency installation.
- Admin Web Docker build installs only the `@zabisa/admin-web` workspace dependency graph.
- Local mobile bootstrap and README use the same `npm ci` contract.
- `scripts/verify-node-lockfile.mjs` verifies offline that root/workspace manifests remain synchronized with `package-lock.json`.
- Offline preflight invokes the lockfile verifier.

## Invariant

`package-lock.json` is a build input and must be committed whenever `package.json` or a workspace `package.json` changes dependencies.

`npm install <package>` is still the correct developer action when intentionally adding/updating a dependency because it updates the manifest and lockfile. Build, CI, and clean bootstrap paths must use `npm ci`.

## Scope intentionally deferred

Hotfix 0.2.2 does not change Harbor push behavior, image inventory, or GitOps image mutation. Admin image pipeline completeness and immutable image publishing remain Hotfix 0.2.3.

This hotfix makes the Node dependency graph lockfile-authoritative; it does not claim byte-for-byte container reproducibility while base images such as `node:22-alpine` remain tag-based. Base-image provenance/pinning belongs to the image-pipeline hardening phase.
