# DT2 — Vault identities, CA bootstrap and in-cluster credential proof

DT1 is complete when the provisioner and independent live verifier both pass.
An application-account login attempted from an operator workstation is not a
valid synchronization test: the MySQL accounts intentionally accept only the
bounded Calico source network, while the database may observe the workstation's
NAT address.

DT2 reuses the existing Vault installation, injector, Kubernetes auth mount,
Calico, namespace and external DB. It does not install duplicate infrastructure.

## Order

1. Establish the existing authenticated Vault port-forward and operator env.
2. Run `bootstrap-zabisa-dt2-vault.sh --plan`.
3. Run `bootstrap-zabisa-dt2-vault.sh --apply` once approved.
4. Run `bootstrap-zabisa-dt2-vault.sh --verify`.
5. Run `run-zabisa-mysql-credential-canary.sh`.

The canary uses the real identity runtime and migrator ServiceAccounts, Vault
roles, KV paths, CA secrets, `db-dt` Service/EndpointSlice and MySQL egress
label. It proves both Vault-to-pod delivery and MySQL password authentication
from the intended network boundary. Both temporary pods are deleted.

The runner waits for the explicit sanitized authentication result. Kubernetes
Pod `Ready` alone is not treated as success because a freshly started cached
image can become Ready immediately before its first log line is emitted.

Do not widen MySQL accounts to `%` or add a workstation/NAT address merely to
make an external test pass. Do not run migrations or ArgoCD sync until the DT2
canary is green.
