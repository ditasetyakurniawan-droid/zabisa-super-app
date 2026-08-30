# Admin Source Invariants

Phase 3.4.1 quality checks distinguish **authored source** from generated and third-party code.

Authored source scope:

- `apps/admin-web/app`
- `apps/admin-web/components`
- `apps/admin-web/lib`
- explicit configuration assertions for `providers.tsx`, `package.json`, and `eslint.config.mjs`

The invariant scanner MUST NOT interpret `.next/**` or `node_modules/**` as Zabisa source. Those directories contain generated Next.js types and third-party declarations which legitimately contain `any`.

`eslint --max-warnings=0` remains the authoritative TypeScript/React lint gate for authored Backoffice code. The source-invariant script is an additional architecture guard, not a replacement for ESLint or TypeScript.
