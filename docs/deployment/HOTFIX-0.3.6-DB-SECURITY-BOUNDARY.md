# Hotfix 0.3.6 — DB TLS + Runtime/Migrator Boundary

## Why

Cluster proof established that `db-dt` resolves to `192.168.100.70` and TCP/3306 reaches the Docker Compose MySQL 8.0 instance. The DB server exposes TLS 1.2/1.3 with an auto-generated CA/server certificate, but `require_secure_transport=OFF`; therefore Zabisa must fail closed on the client side without changing shared MySQL behavior for unrelated applications.

The seven Go services previously executed embedded migrations during every process startup. That would force the long-lived runtime account to hold DDL privileges. Hotfix 0.3.6 separates migration and runtime identities.

## Runtime contract

DT runtime Deployments use:

- `APP_MODE=serve`
- `MYSQL_TLS_MODE=verify-ca`
- `MYSQL_TLS_CA_FILE=/mysql/tls/ca.pem`
- runtime Vault path `kv/data/zabisa/dt/<service>/database`
- runtime ServiceAccount `zabisa-<service>`

Runtime pods do **not** execute embedded migrations.

## Migration contract

Seven ArgoCD `PreSync` Jobs use:

- `APP_MODE=migrate`
- the same immutable service image as runtime
- `MYSQL_TLS_MODE=verify-ca`
- migration-only ServiceAccount `zabisa-<service>-migrator`
- migration-only Vault role `app-zabisa-<service>-migrator-dt`
- migration-only KV path `kv/data/zabisa/dt/<service>/migrator`
- no JWT signing key and no internal-service key

The migration Job exits after migrations complete. Local development keeps `serve-with-migrations` as the default to preserve developer experience.

## TLS semantics

`verify-ca` requires TLS 1.2+ and verifies the server certificate chain against the pinned MySQL CA. Hostname verification is intentionally not performed because MySQL auto-generated certificates do not carry the Kubernetes service DNS identity. The implementation does **not** accept an unverified chain and does not fall back to plaintext.

`verify-identity` is implemented for future use after the DB server is given a certificate whose SAN/CN matches the stable DB hostname.

The MySQL CA certificate is external infrastructure material and is not committed to Git. Bootstrap it as `Secret/zabisa-app/mysql-ca` with exactly one key, `ca.pem`.

## Intended MySQL privilege split

For each bounded-context database:

Runtime account:

- `SELECT`
- `INSERT`
- `UPDATE`
- `DELETE`

Migrator account:

- runtime DML privileges above
- `CREATE`
- `ALTER`
- `INDEX`
- `REFERENCES`

`DROP` is intentionally not granted because current immutable migrations do not require it.

Actual account creation and KV values are an operator action and are not performed by this hotfix.

## First-deploy ordering

1. Apply repository hotfix and offline preflight.
2. Export the existing MySQL CA from `mysql-db` and bootstrap `zabisa-app/mysql-ca`.
3. Re-run platform prerequisites so seven migration ServiceAccounts exist.
4. Configure seven migration-only Vault policies/roles.
5. Provision seven databases + runtime/migrator MySQL accounts with `REQUIRE SSL` and restricted client host/CIDR.
6. Write runtime/migrator DB credentials to their Vault KV paths.
7. Render immutable GitOps manifests.
8. ArgoCD PreSync migration Jobs run before Deployments.
9. Runtime Deployments start with DML-only accounts.

Do not enable global MySQL `require_secure_transport` until every other application sharing `DB-dt` has been audited for TLS compatibility.
