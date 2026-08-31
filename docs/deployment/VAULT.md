# Vault integration — DT

## Existing platform contract

Zabisa reuses the existing HashiCorp Vault installation; it does not install another Vault or another injector.

Verified DT characteristics (2026-08-31):

- Vault namespace: `vault`.
- Vault server service: `vault.vault.svc`, TCP `8200/8201`.
- Vault Agent Injector image: `hashicorp/vault-k8s:1.7.5`.
- Injector webhook: `vault-agent-injector-cfg`.
- Kubernetes auth path: default `auth/kubernetes` (existing working pods do not override `auth-path`).
- Existing workload token convention: projected ServiceAccount token volume `vault-token`, audience `vault`, expiration `3600`, path `token`.
- Vault TLS: namespace-local Secret named `vault-ca`, key `ca.crt`; `ca-cert=/vault/tls/ca.crt`; TLS server name `vault.vault.svc`.
- Existing workloads use role-per-workload patterns.

## Zabisa identity model

Every Go bounded context receives its own Kubernetes ServiceAccount and Vault role/policy:

| Workload | Kubernetes ServiceAccount | Vault role | Vault policy |
|---|---|---|---|
| api-gateway | `zabisa-api-gateway` | `app-zabisa-api-gateway-dt` | `zabisa-api-gateway-dt` |
| identity | `zabisa-identity` | `app-zabisa-identity-dt` | `zabisa-identity-dt` |
| content | `zabisa-content` | `app-zabisa-content-dt` | `zabisa-content-dt` |
| student | `zabisa-student` | `app-zabisa-student-dt` | `zabisa-student-dt` |
| tahfidz | `zabisa-tahfidz` | `app-zabisa-tahfidz-dt` | `zabisa-tahfidz-dt` |
| academic | `zabisa-academic` | `app-zabisa-academic-dt` | `zabisa-academic-dt` |
| donation | `zabisa-donation` | `app-zabisa-donation-dt` | `zabisa-donation-dt` |
| notification | `zabisa-notification` | `app-zabisa-notification-dt` | `zabisa-notification-dt` |

`admin-web` currently has no runtime secret requirement and therefore receives no Vault Agent. Its Kubernetes ServiceAccount has automatic token mounting disabled.

## KV v2 paths

Shared cryptographic/inter-service material:

```text
kv/data/zabisa/dt/shared/runtime
  JWT_SIGNING_KEY
  INTERNAL_SERVICE_KEY
```

Database credentials are separated per bounded context:

```text
kv/data/zabisa/dt/identity/database
kv/data/zabisa/dt/content/database
kv/data/zabisa/dt/student/database
kv/data/zabisa/dt/tahfidz/database
kv/data/zabisa/dt/academic/database
kv/data/zabisa/dt/donation/database
kv/data/zabisa/dt/notification/database

fields:
  MYSQL_USER
  MYSQL_PASSWORD
```

The preferred DB end-state is a different MySQL account/grant per bounded context. If DT temporarily reuses one MySQL user, values may initially be duplicated between Vault paths, but the path/policy boundary is retained so DB grants can be tightened without changing application manifests.

## Secret consumption

Vault Agent renders files into `/vault/secrets`. The Go platform config loader supports:

```text
MYSQL_USER_FILE
MYSQL_PASSWORD_FILE
JWT_SIGNING_KEY_FILE
INTERNAL_SERVICE_KEY_FILE
```

`*_FILE` takes precedence over a same-named direct environment variable. A missing/unreadable/empty secret file fails runtime validation at startup.

Go images remain distroless/non-root. The application container explicitly runs as UID/GID `65532`, and `vault.hashicorp.com/agent-run-as-same-user=true` makes injected Vault Agent containers use the same application UID. Rendered files therefore remain mode `0400` without requiring a shell wrapper or world/group-readable secrets.

## First deployment order

Do not enable ArgoCD application sync before Vault prerequisites exist.

1. Write KV values to the paths above using the existing Vault administrative workflow.
2. Apply policies from `deploy/vault/policies/` and Kubernetes auth roles using `scripts/configure-zabisa-vault-auth.sh` from an authenticated Vault CLI environment.
3. Bootstrap namespace/ServiceAccounts/NetworkPolicies and copy the existing CA-only `vault-ca` Secret:

   ```bash
   ./scripts/bootstrap-zabisa-platform-prereqs.sh test-app
   ```

   `test-app` is only an example source namespace known to contain the existing `vault-ca`; any trusted namespace with an identical CA-only secret may be supplied.
4. Run `./scripts/verify-cluster-vault-compat.sh`.
5. Render/publish immutable GitOps manifests and let ArgoCD perform application deployment.
6. Verify each Go pod has `vault-agent-init` + `vault-agent` and reaches Ready state.

The repository never stores real KV values, Vault tokens, database passwords, JWT signing keys or private key material.
