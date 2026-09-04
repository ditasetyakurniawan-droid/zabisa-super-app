# DT4 — Immutable image build and Harbor publication

Status: **SOURCE HARDENING / BUILD AND PUSH NOT RUN**

Source baseline: `4783fa6`

Discovery date: `2026-09-04`

## Objective

Produce nine reviewable `linux/amd64` application images from one clean Git
commit. Every image must pass the HIGH/CRITICAL vulnerability gate, have a
CycloneDX SBOM, retain its source revision label, be pushed through trusted TLS,
and have its Harbor digest recorded before DT4 can close.

Seven of the images are used by both runtime Deployments and migration Jobs:
`identity`, `content`, `student`, `tahfidz`, `academic`, `donation`, and
`notification`. `api-gateway` and `admin-web` complete the application inventory.

## Live discovery evidence

- Source `4783fa6` and Engineering Quality Gate were verified.
- Docker `29.7.2` and buildx `0.36.1` are available.
- All six Kubernetes nodes are `linux/amd64` with containerd `2.2.6`.
- Harbor resolves to `192.168.100.58`.
- Workstation Harbor TLS failed because the issuing CA is not trusted locally.
- Trivy is not installed on the workstation.
- No ServiceAccount in `zabisa-app` references an `imagePullSecret`, and the
  namespace contains no Docker config Secret. Node-level auth/trust or anonymous
  project pull therefore remains unproven.
- The old build script did not record or compare the post-push Harbor digest.

Discovery report SHA-256:
`dad2aaa1fa85312683bc7a85820e922ade942453ba906a4a12f9508628cf338b`.

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

1. Obtain the existing Harbor issuing CA through an approved platform source.
2. Verify its fingerprint out-of-band, install it into workstation Docker and
   OS trust, restart Docker only if required, then prove `/v2/` returns 200/401
   without `-k`.
3. Install a pinned safe Trivy release and verify its artifact checksum. The
   `2026-03-19` Trivy security advisory requires a known-safe release rather
   than `latest`.
4. Confirm who owns execution: existing Jenkins with a configured credential ID
   or a controlled workstation run. Credentials remain external to Git.
5. Prove Harbor project `zabisa` exists and the push identity has bounded write
   access.
6. Prove cluster pull using the existing platform mechanism or add a dedicated
   namespace imagePullSecret through a separately reviewed bootstrap change.
7. Review the image/SBOM/scan/digest evidence and approve DT4 closure.

## Stop conditions

Stop without pushing when:

- source is dirty or SHA differs;
- a base digest differs;
- Harbor TLS is untrusted;
- Trivy is missing or outside the approved version;
- any HIGH/CRITICAL finding causes a non-zero scan result;
- an image ID changes after scanning;
- a push succeeds but remote digest proof fails;
- cluster pull authentication is unknown.

Do not use `--insecure`, `--tls-verify=false`, `curl -k`, mutable tags, manual
manifest edits, or imperative Kubernetes deployment to bypass a gate.

## Authorization boundary

DT4 source hardening does not authorize `docker login`, image push, Kubernetes
mutation, database migration, application Deployment or ArgoCD sync. Those
actions require later explicit confirmations for their exact targets.
