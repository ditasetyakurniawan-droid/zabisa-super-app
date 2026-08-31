# Hotfix 0.3.3 — Vault Agent end-to-end canary

Purpose: prove the existing DT Vault Agent Injector contract end-to-end before provisioning Zabisa production credentials or deploying application workloads.

The canary is deliberately temporary and uses:
- namespace `zabisa-app`
- existing ServiceAccount `zabisa-api-gateway`
- projected service-account token with audience `vault`, 3600-second expiration
- temporary Vault policy/role `zabisa-canary`
- temporary KV v2 key `kv/zabisa/dt/canary`
- `vault-ca` TLS trust and `vault.vault.svc` server name
- `agent-pre-populate-only=true` so only the init container is injected
- file permission `0400`

The temporary workload policy grants only `read` on `kv/data/zabisa/dt/canary`.
The runner refuses to overwrite pre-existing canary policy, role, KV metadata or Pod objects.
On success or failure after mutation begins, cleanup attempts to remove the Pod, role, policy, and all KV v2 metadata/versions for the temporary canary path.

`apply-hotfix-0.3.3.sh` is offline and non-mutating. `run-vault-canary.sh` is the explicit mutating test.
