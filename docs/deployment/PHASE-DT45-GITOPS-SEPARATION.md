# Phase DT4.5 — GitOps Repository Separation

## Decision

Zabisa follows the existing Tropical delivery pattern with two repositories:

- `zabisa-super-app` owns application source, tests, Dockerfiles, Jenkinsfile,
  deployment templates, validation scripts and developer documentation;
- `zabisa-super-app-gitops` owns the rendered DT desired state consumed by
  ArgoCD under `apps/zabisa/overlays/dt`.

Jenkins builds and scans nine images, pushes immutable full-Git-SHA tags to
`harbor-dt.co.id/zabisa`, verifies the Harbor digests, renders the Kubernetes
templates, then commits the rendered overlay to the GitOps repository. Jenkins
never runs an imperative application deployment. ArgoCD remains the deployment
authority and sync remains manual.

## Included source corrections

- remove the unsupported Trivy 0.74.0 `--disable-telemetry` CLI flag;
- keep the digest-pinned Dockerized Trivy pre-push scan and CycloneDX SBOM;
- use Sonar-only TypeScript configs compatible with the private Sonar analyzer
  without changing application `moduleResolution=bundler` behavior;
- restrict Jenkins multibranch discovery to `main`, clear automatic triggers
  and keep the parent job disabled outside a controlled run;
- publish rendered manifests to the dedicated GitOps repository using an
  existing Jenkins credential identifier and `GIT_ASKPASS`;
- remove only exact Zabisa build images and the Jenkins workspace after
  archived evidence is retained.

## GitOps layout

```text
zabisa-super-app-gitops/
├── README.md
├── bootstrap/
│   └── argocd-application.yaml
└── apps/zabisa/overlays/dt/
    ├── README.md
    ├── SOURCE_REVISION
    ├── kustomization.yaml
    └── manifests/*.yaml
```

`SOURCE_REVISION` and every workload image tag must identify the same full
source commit. The files below `manifests/` are generated and must not be
edited manually.

## Execution boundary

Committing this phase does not build or push images, apply the ArgoCD
Application, run migration Jobs, or sync workloads. Live DT4.3/DT4.4 delivery
must pass before the backup/migration and ArgoCD sync runbook is authorized.
