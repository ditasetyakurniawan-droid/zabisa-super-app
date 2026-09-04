# Hotfix 0.2.3 — Immutable Image Pipeline Baseline

## Goal
Make the container image path explicit, complete, immutable and auditable without requiring Kubernetes access.

## Image inventory
Exactly nine deployable images are owned by this repository:

1. `api-gateway`
2. `identity`
3. `content`
4. `student`
5. `tahfidz`
6. `academic`
7. `donation`
8. `notification`
9. `admin-web`

All image tags are full/validated Git object IDs; `:latest` is prohibited in production build/deployment paths.

## Build / scan / SBOM / push
`scripts/build-images.sh` has explicit modes. The normal Jenkins path is:

- every branch: build all nine images;
- Trivy HIGH/CRITICAL vulnerability gate;
- CycloneDX SBOM per image archived by Jenkins;
- `main`: authenticate to Harbor using Jenkins Credentials and push the already-scanned SHA-tagged images;
- `main`: render Kubernetes manifests with the same SHA and archive them as a GitOps handoff artifact.

The build script never performs `docker login` itself and never creates `:latest`. Registry credentials remain external to the repository.

## GitOps honesty rule
`scripts/update-gitops.sh` now performs a real deterministic render of the base manifests and verifies all nine placeholders are replaced. It deliberately does **not** claim to publish to a GitOps repository because the actual GitOps repository URL/credential workflow has not yet been supplied.

ArgoCD remains the intended deployment authority. A later integration must commit the rendered immutable tags into the real GitOps repository rather than deploying imperatively from Jenkins.

## Admin Web Kubernetes baseline
`admin-web` now has a restricted Deployment, Service and PDB in `zabisa-app`.

NetworkPolicy permits:

- ingress to Admin Web only from an explicitly opted-in ingress-controller namespace;
- Admin Web egress only to `api-gateway:8080`;
- API Gateway ingress from Admin Web only on `8080`.

Admin Web has no direct NetworkPolicy path to bounded-context services or MySQL.

## Supply-chain boundary
This hotfix originally established immutable application tags, vulnerability
scanning and SBOM generation while leaving base-image pinning open. DT4.0 later
verified the cluster as `linux/amd64`, resolved the current OCI indexes and
DT4.1 pins those base images by digest. Any future base-image digest change must
remain an explicit reviewed source change.

Image-pull authentication is also intentionally not guessed here. Kubernetes must use the cluster's approved Harbor pull mechanism (node/container-runtime auth or a dedicated imagePullSecret/ServiceAccount policy). Vault Agent injection cannot solve image-pull authentication because image pull occurs before application containers start.

## Offline verification

```bash
./scripts/verify-image-pipeline.sh
./scripts/build-images.sh "$(git rev-parse HEAD)" --plan
./scripts/preflight-offline.sh
```

These checks require no Kubernetes API and perform no registry push.
