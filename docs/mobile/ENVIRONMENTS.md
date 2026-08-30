# Mobile Environments

Runtime config is written to `apps/mobile/src/config/runtime.ts` by `scripts/mobile-env.sh`.

## Local

```bash
ZABISA_ENV=local npm run mobile:env
```

Default: `http://127.0.0.1:8088`, intended only with ADB reverse.

## DT / staging / production

A URL is mandatory and must use HTTPS:

```bash
ZABISA_ENV=dt ZABISA_API_URL=https://api-dt.example.org npm run mobile:env
ZABISA_ENV=staging ZABISA_API_URL=https://api-staging.example.org npm run mobile:env
ZABISA_ENV=production ZABISA_API_URL=https://api.zabisa.example.org npm run mobile:env
```

Do not put passwords, API secrets, payment credentials, FCM service-account secrets or private keys in `runtime.ts`.
