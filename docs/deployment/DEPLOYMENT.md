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

The DT image inventory contains nine images: eight Go backend services plus
`admin-web`. Builds use the full Git SHA, a clean worktree, the verified
`linux/amd64` platform and digest-pinned application base images; `:latest` is
not used. Trivy HIGH/CRITICAL JSON scanning and CycloneDX SBOM generation happen
before a `main`-branch Harbor push. The push gate binds that evidence to the
local image ID and verifies the resulting remote Harbor digest.

`admin-web` has a separate frontend boundary and no Vault injection because it currently requires no secret. Its only application egress is to the API gateway.

## Existing delivery path

GitHub Actions owns source quality and Browser E2E. The existing Docker Compose
Jenkins at `192.168.100.57` owns private Sonar and, after separate approvals,
Dockerized Trivy, SBOM generation, Harbor publication and GitOps rendering.
Zabisa reuses `github-credentials-id`, `harbor-cred`, `sonar-dt` and the
established Docker socket/Harbor compatibility contract.

The Multibranch job `zabisa-super-app-v1` was cloned from the proven
`tropical-management-v1` pattern. It is disabled, contains no automatic
trigger and has never indexed or built a branch. See
`../runbook/JENKINS_DELIVERY.md` before changing that state.

The repository can render immutable GitOps manifests with
`scripts/update-gitops.sh`. Publishing or applying a rendered result remains a
separate gate; ArgoCD remains deployment authority.

The first Dockerized Trivy execution, Harbor publication, cluster image-pull
authentication and real GitOps publication remain explicit live gates. TLS
bypass flags must not be added to Zabisa pipeline source.
