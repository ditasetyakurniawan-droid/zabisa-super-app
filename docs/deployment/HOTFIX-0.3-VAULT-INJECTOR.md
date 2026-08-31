# Hotfix 0.3 — Vault Agent Injector

This hotfix aligns Zabisa with the existing DT Vault implementation rather than introducing a new secret mechanism.

## Changes

- per-workload Kubernetes ServiceAccounts with automatic default token mounting disabled;
- explicit projected tokens for Vault Kubernetes auth (`audience=vault`, `expirationSeconds=3600`);
- Vault Agent annotations using the existing `vault-ca` TLS pattern and `vault.vault.svc` identity;
- `agent-run-as-same-user` plus explicit distroless UID/GID `65532` so `0400` rendered files are readable only by the application/Vault Agent UID;
- per-bounded-context Vault policy files;
- `*_FILE` support and fail-fast config validation in Go;
- Vault egress restricted by Calico to Vault server pods on TCP/8200;
- MySQL egress narrowed to explicitly labeled stateful services;
- ingress NetworkPolicies bound directly to the discovered existing `ingress-nginx` labels;
- secure CA bootstrap helper that copies only `ca.crt` without printing certificate data;
- Vault auth role configuration helper that never writes KV values.

## Deliberately not automated

- real KV secret values;
- Vault administrative authentication/token acquisition;
- MySQL user/grant creation;
- ArgoCD sync/deployment.

Those operations are environment-specific and/or secret-bearing and must remain explicit.
