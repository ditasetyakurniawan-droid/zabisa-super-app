# DT4 — Immutable image build and Harbor publication

Status: **DT4.1 SOURCE PASS / DT4.2 JOB CREATION READY**

Source baseline: `df2d275`

Discovery date: `2026-09-04`

## Objective

Produce nine reviewable `linux/amd64` application images from one clean Git
commit. Every image must pass the HIGH/CRITICAL vulnerability gate, have a
CycloneDX SBOM, retain its source revision label, use the existing
Jenkins/Harbor delivery contract, and have its Harbor digest recorded before
DT4 can close.

Seven of the images are used by both runtime Deployments and migration Jobs:
`identity`, `content`, `student`, `tahfidz`, `academic`, `donation`, and
`notification`. `api-gateway` and `admin-web` complete the application inventory.

## Live discovery evidence

- Source `4783fa6` and Engineering Quality Gate were verified.
- Docker `29.7.2` and buildx `0.36.1` are available.
- All six Kubernetes nodes are `linux/amd64` with containerd `2.2.6`.
- Harbor resolves to `192.168.100.58`.
- Jenkins is the existing Compose service `jenkins-server` on
  `192.168.100.57`, with Java 17, Docker CLI/socket, Git, two built-in executors
  and the required Pipeline/Sonar plugins.
- The proven `tropical-management-v1` Multibranch job uses
  `github-credentials-id`, `harbor-cred`, private Sonar, Docker build/push and
  GitOps update stages.
- Harbor 2.10 is healthy on `192.168.100.58`. Its current certificate identifies
  the IP address, while Jenkins reaches `harbor-dt.co.id` through the existing
  Docker daemon `insecure-registries` compatibility contract. Other workloads
  already use this path successfully.
- DT4.2 does not alter that shared Harbor/TLS configuration. Pipeline source is
  still forbidden from adding `--insecure`, `--tls-verify=false` or `curl -k`.
- Trivy is absent from the Jenkins controller image. Zabisa invokes the official
  Trivy image through the existing Docker socket, pinned to version `0.74.0`
  and OCI index digest
  `sha256:62b1e65e8869bc4b4c6aa4fa2b21595256c7c2f6018a9d9ad61caf87187c1969`.
- No ServiceAccount in `zabisa-app` references an `imagePullSecret`, and the
  namespace contains no Docker config Secret. Node-level auth/trust or anonymous
  project pull therefore remains unproven.
- The old build script did not record or compare the post-push Harbor digest.

Discovery report SHA-256:
`dad2aaa1fa85312683bc7a85820e922ade942453ba906a4a12f9508628cf338b`.

Compose/Jenkins alignment evidence SHA-256:

- `b1168460b5eb6f67f1e75ba9dc557db272e73aa0b679e75a0a96b3fbce8739b`
  (Jenkins/Harbor Compose inventory);
- `e64be7e2e4fa3d63282a2a7b1ca65a3ab5b20faa536e316650f9475e9a3c158d`
  (existing Multibranch, Sonar, Harbor and GitOps delivery pattern).

## Reviewed base-image indexes

The discovery resolved these multi-architecture OCI index digests. DT4 source
pins them while the build contract selects `linux/amd64`:

| Image | OCI index digest |
|---|---|
| `golang:1.26.7-alpine` | `sha256:28d89ee9cc0ff9fec75c82ca201e6bf7fdf9a679d4b7b24dfa04f2bb766bb468` |
| `gcr.io/distroless/static-debian12:nonroot` | `sha256:afa5c872c891853ca7fcf1f12c3edb23f7eeef36189728842dd51042ff57f7ab` |
| `node:22-alpine` | `sha256:c610fcdfb1d5b4740dd70c284ed3cb16bb857e0f7166196e36a5501df7a3aa32` |

Changing any digest is a reviewed source change, never an implicit pull of a
new mutable tag.

## Source-enforced build contract

`scripts/build-images.sh` requires:

- the full 40-character HEAD SHA;
- a clean worktree;
- `linux/amd64`;
- all nine builds before scan/push completion;
- a matching OCI revision label;
- Trivy JSON and CycloneDX output per image;
- a scan attestation bound to the local image ID, revision and evidence hashes;
- validation of every attestation before the first push;
- remote digest inspection after push;
- equality between the locally recorded RepoDigest and Harbor digest;
- a final `harbor-digests-<SHA>.tsv` evidence file.

The script never logs in, requests a password, disables TLS, deploys Kubernetes
resources or invokes ArgoCD.

## Remaining live gates

1. Commit and pass GitHub source/browser gates for the DT4.2 alignment.
2. Render the Zabisa Multibranch job from `tropical-management-v1`, using
   `github-credentials-id`; clear automatic triggers and create it disabled.
3. Review the disabled job configuration before any indexing/build.
4. Prove the pinned Dockerized Trivy version and vulnerability DB download on
   the Jenkins executor.
5. Prove Harbor project `zabisa` exists and `harbor-cred` has bounded write
   access using a separately approved canary publication.
6. Build, scan and push the nine images from one clean approved commit, then
   verify all remote digests.
7. Prove worker/containerd trust and cluster pull using the existing platform
   mechanism, or add a dedicated
   namespace imagePullSecret through a separately reviewed bootstrap change.
8. Review the Jenkins image/SBOM/scan/digest evidence and approve DT4 closure.

## Stop conditions

Stop without pushing when:

- source is dirty or SHA differs;
- a base digest differs;
- the existing Jenkins Docker daemon cannot authenticate/push through its
  established Harbor contract;
- Trivy is missing or outside the approved version;
- any HIGH/CRITICAL finding causes a non-zero scan result;
- an image ID changes after scanning;
- a push succeeds but remote digest proof fails;
- cluster pull authentication is unknown.

Do not add `--insecure`, `--tls-verify=false`, `curl -k`, mutable tags, manual
manifest edits, or imperative Kubernetes deployment to pipeline source. The
shared daemon-level compatibility exception is documented as existing platform
state and is not broadened by Zabisa.

## Authorization boundary

DT4 source hardening does not authorize `docker login`, image push, Kubernetes
mutation, database migration, application Deployment or ArgoCD sync. Those
actions require later explicit confirmations for their exact targets.
