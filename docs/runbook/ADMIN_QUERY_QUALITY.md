# Admin Query Quality Validation

Run from repository root:

```bash
npm run admin:typecheck
npm run admin:lint
npm run admin:build
npm run phase34:verify
npm run demo:verify
```

Expected invariants:

1. no `react-hooks/set-state-in-effect` error;
2. no explicit `any` in `apps/admin-web` TypeScript source;
3. production Next.js build succeeds;
4. RBAC integration remains green;
5. development demo regression remains green.

Do not downgrade React Hooks rules to make the build pass.
