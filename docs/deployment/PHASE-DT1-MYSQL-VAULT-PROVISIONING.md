# DT Deployment Track 1 - MySQL and Vault provisioning

This track provisions the database identities required before the first Zabisa
ArgoCD sync. It targets the existing MySQL server at `db-dt` and the existing
Vault KV v2 mount. It does not install MySQL or Vault, deploy application pods,
or write any credential to Git.

## Security decisions

- Seven service-owned databases use `utf8mb4` and `utf8mb4_unicode_ci`.
- Every service receives a DML-only runtime account and a separate migrator
  account with only the DML/DDL privileges required by current migrations.
- Every MySQL account has `REQUIRE SSL` and `PASSWORD EXPIRE NEVER`; credential
  rotation remains an explicit operator action through `--rotate`.
- Existing direct grants are reset before the exact runtime or migrator grant is
  applied. Live verification also rejects global privileges and role grants.
- MySQL account sources use canonical IPv4 CIDR/netmask scope or an exact IPv4
  address. `%` and `_` wildcards are rejected, and sources broader than `/16`
  fail closed. The current Calico pool is `192.168.0.0/16`; because DB-dt is
  inside that pool and external to Kubernetes, MySQL observes pod source IPs
  rather than a stable list of worker-node IPs. The DT input is therefore
  `MYSQL_ACCOUNT_NETWORKS=192.168.0.0/16`, normalized for MySQL to
  `192.168.0.0/255.255.0.0`.
- Kubernetes remains the narrower enforcement boundary: only labeled Zabisa
  database clients may egress to `192.168.100.70/32:3306`. This follows the
  working external `db-dt` pattern without changing the existing Calico pool.
- MySQL administrative access uses `VERIFY_CA` and a protected temporary option
  file. The admin password is never placed in process arguments.
- Existing Vault credentials are reused on an ordinary rerun, preventing Vault
  and MySQL password drift. `--rotate` intentionally generates new credentials
  and reconciles MySQL before writing the new Vault versions.
- A Vault authorization or transport failure is never interpreted as a missing
  secret; provisioning fails before rotating the corresponding MySQL account.
- Vault database passwords are sent on standard input and are never printed.

## Vault paths

The CLI uses `-mount=kv` with paths below the mount:

```text
zabisa/dt/<service>/database
zabisa/dt/<service>/migrator
```

Vault Agent policies and Kubernetes annotations use the corresponding KV v2
API paths:

```text
kv/data/zabisa/dt/<service>/database
kv/data/zabisa/dt/<service>/migrator
```

Each secret contains exactly the application-facing fields `MYSQL_USER` and
`MYSQL_PASSWORD`.

## Modes

- `--plan`: validates tools, certificates, MySQL TLS, Vault authentication,
  existing Zabisa account scope and target mapping without mutation.
- `--apply`: reuses valid existing Vault passwords or generates missing
  64-character hexadecimal passwords, reconciles MySQL, then writes Vault.
- `--rotate`: explicitly rotates every runtime and migrator password.
- verifier `--source`: offline invariant validation.
- verifier `--live`: checks schemas, bounded-source accounts, TLS requirements,
  direct schema privileges, absence of global privileges, and all Vault fields.

The admin credential must be supplied through a mode-0600 file referenced by
`MYSQL_ADMIN_PASSWORD_FILE`. Both `MYSQL_SSL_CA` and `VAULT_CACERT` must point
to readable CA files. `VAULT_ADDR` must use HTTPS.

The provisioning path requires an Oracle MySQL client that supports
`--ssl-mode=VERIFY_CA`. Ubuntu may expose a MariaDB client through the `mysql`
command; that client is deliberately rejected instead of silently weakening
certificate verification. Operators can set
`MYSQL_CLIENT_BIN=./scripts/mysql-client-docker.sh` to use the repository's
digest-pinned MySQL 8.4 client runner. The pinned image must be pulled and
reviewed explicitly before use; the wrapper never pulls a mutable image during
provisioning. The runner keeps Docker standard input attached because rendered
account SQL is streamed to the client rather than written to a credential-bearing
file.

`deploy/local/mysql/01-zabisa-users.sql` is an operator-rendered template, not
a local-development initialization script. Docker Compose mounts only
`00-databases.sql`, preventing placeholder accounts from being created during
local startup and isolated browser E2E.

## Existing-platform alignment

- MySQL stays on the existing external `db-dt` VM; no in-cluster MySQL is
  introduced.
- Vault, Vault CA, ServiceAccounts, ingress-nginx, MetalLB, and Harbor access
  are reused; this track installs none of them.
- The only application boundary is the existing `zabisa-app` namespace and its
  stricter NetworkPolicies.
- No `imagePullSecret`, LoadBalancer, Calico pool, or new shared infrastructure
  is created by this provisioning workflow.

## Failure and recovery

MySQL account-management statements are not transactional. The workflow is
therefore deliberately rerunnable. If execution stops after only some MySQL or
Vault writes, rerun `--apply`; existing Vault passwords are reused and every
account is reconciled to the same value before verification.

Do not automatically drop databases, users, or Vault versions as rollback.
For an emergency before any application deployment, lock affected MySQL users
through the DBA workflow and restore the prior Vault KV v2 version. Database
deletion always requires a separate backup/retention decision.

## Explicitly out of scope

- shared `JWT_SIGNING_KEY` and `INTERNAL_SERVICE_KEY` provisioning;
- Vault policy/role application;
- MySQL CA Secret bootstrap in Kubernetes;
- image build/push;
- ArgoCD sync and application migrations.

Those gates follow only after this provisioning track passes live verification.
