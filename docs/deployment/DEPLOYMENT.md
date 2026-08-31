# DT deployment

Zabisa deploys into the dedicated Kubernetes namespace `zabisa-app` and integrates with the existing shared DT cluster without changing unrelated workloads.

Verified platform: Kubernetes server `v1.30.14`, Calico CNI, CoreDNS, ingress-nginx, MetalLB, Longhorn, ArgoCD and an existing HA Vault cluster with Vault Agent Injector. Before production apply, use a `kubectl` client within the supported version skew of the server.

All critical application workloads use replicas >= 2, PDBs, non-root containers, dropped capabilities, seccomp `RuntimeDefault`, probes and resource requests/limits. The namespace enforces Pod Security `restricted` and default-deny NetworkPolicy.

## Network baseline

Explicit permitted edges include:

- all Zabisa pods -> CoreDNS TCP/UDP 53;
- Go backend pods -> Vault server pods TCP 8200;
- stateful bounded contexts only -> existing MySQL `192.168.100.70:3306`;
- backend -> backend ports 8080–8087 where current synchronous/outbox implementation requires it;
- existing ingress-nginx controller -> API gateway 8080 and Admin Web 3000;
- Admin Web -> API gateway 8080 only.

No Zabisa NetworkPolicy requires labels or mutations on an unrelated existing namespace.

## Vault

Runtime secret delivery is Vault Agent Injector. See `docs/deployment/VAULT.md`. ArgoCD no longer relies on `CreateNamespace=true`: first-time operators must bootstrap `zabisa-app`, its ServiceAccounts/NetworkPolicies and the namespace-local CA-only `vault-ca` before application sync. This prevents first sync from racing external Vault prerequisites.

## Immutable image pipeline

The DT image inventory contains nine images: eight Go backend services plus `admin-web`. CI builds/scans Git-SHA-tagged images only; `:latest` is not used. Trivy HIGH/CRITICAL scanning and CycloneDX SBOM generation happen before a `main`-branch Harbor push.

`admin-web` has a separate frontend boundary and no Vault injection because it currently requires no secret. Its only application egress is to the API gateway.

The repository can render immutable GitOps manifests locally with `scripts/update-gitops.sh`, but publishing them to the real GitOps repository remains intentionally unimplemented until its actual URL and Jenkins credential workflow are configured. ArgoCD remains deployment authority.

Base-image digest pinning, Harbor image-pull authentication and real GitOps repository publication remain explicit pre-production follow-ups.
