# Zabisa Demo Data Runbook

## Populate

```bash
npm run demo:seed
```

The command must end with:

```text
=== FULL DEVELOPMENT DATA: READY ===
```

## Verify

```bash
npm run demo:verify
```

The verifier requires populated public content, donation states, two linked students, tahfidz, grades, attendance, reports, donation history and notifications.

Expected final line:

```text
=== RESULT: PASS ===
```

## Safety

The scripts refuse DT, staging, production, LAN hostnames/IPs, or any target other than localhost/127.0.0.1/::1.

Do not weaken this guard to make production look populated. Production data must come through approved operational workflows.

## Reset strategy

Development seed data is deliberately additive/idempotent rather than destructive. Do not add a `DELETE ALL` shortcut to shared development databases. For a completely clean local reset, recreate the local Docker volumes according to the local-development runbook.
