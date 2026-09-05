# Local Development

## Repository

Expected local repository:

```text
~/project-homelab/zabisa-super-app
```

## Platform start/status

Use Docker Compose from repository root.

Useful checks:

```bash
docker compose ps
curl -fsS http://127.0.0.1:8088/health/live
curl -fsS http://127.0.0.1:3001/login >/dev/null
```

### Legacy local migration recovery

If Backoffice returns 502 while `admin-web`, gateway and MySQL ports are bound,
inspect the service logs. The exact message `legacy records without checksums`
means an old **local demo** volume predates checksum-enforced migrations. This
is not a port collision and unrelated homelab services must not be stopped.

The controlled recovery backs up all local databases, validates the Compose
volume label, stops only Zabisa, removes only its `mysql_data` volume, rebuilds
the stack and runs the local vertical-slice proof:

```bash
ZABISA_LOCAL_RESET_CONFIRM=RESET-ZABISA-LOCAL-DEMO-DB \
  ./scripts/reset-local-development-db.sh --run
```

Backups are written with owner-only permissions below
`~/project-homelab/zabisa-local-db-backups/`. Never use this local recovery for
DT MySQL, Kubernetes migration jobs or ArgoCD.

## Local endpoints

- Backoffice: `http://localhost:3001`
- API Gateway: `http://127.0.0.1:8088`
- MySQL host port: `3307`
- NATS: `4222`
- NATS monitoring: `8222`
- MinIO API: `9000`
- MinIO console: `9001`

## Backoffice

Use `localhost:3001` consistently for Browser E2E/session-cookie behavior.

Production container runs Next standalone generated server and exposes
container port 3000 through host 3001.

## Mobile Metro

Zabisa Metro uses host port 8082.

Physical-device development requires:

```text
adb reverse tcp:8081 tcp:8082
adb reverse tcp:8088 tcp:8088
```

Do not repurpose/kill the unrelated host process on 8081.

## OPPO notes

ADB can briefly disappear during USB mode re-enumeration. Before debugging
Gradle or the app, first check:

```bash
$HOME/Android/Sdk/platform-tools/adb devices -l
```

Keep device unlocked, accept RSA prompt and use a data-capable USB mode.

Do not use package `pm clear` on the verified OPPO workflow.

## Go/Node

- Go baseline: 1.26.7
- local Node observed: 24.x
- Backoffice container: Node 22 Alpine

Do not change runtimes merely because they differ unless a reproducible build
or compatibility issue requires it.

## Safe failure behavior

Installer/hotfix scripts should stop on real failures but should not use a
top-level interactive-shell `exit` command that closes the user's terminal.

Never use force-push or destructive Git reset as part of routine development.
