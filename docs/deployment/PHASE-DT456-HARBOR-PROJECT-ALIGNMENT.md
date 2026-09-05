# DT4.5.6 — Harbor Project Alignment

## Build #12 evidence

Jenkins build `#12` passed GitHub source quality, private SonarQube, the Quality
Gate, Trivy readiness, all nine image builds and all nine vulnerability scans.
The first push failed immediately after a successful robot login:

```text
harbor-dt.co.id/v2/zabisa/api-gateway/...: 401 Unauthorized
```

The credential was valid. The repository path was not: `devops-robot` is a
Project Admin for the existing Harbor project `devops-apps`, while the Zabisa
pipeline incorrectly targeted the nonexistent/unauthorized project `zabisa`.

## Correction

DT4.5.6 changes only the Harbor project segment and preserves the nine reviewed
repository names:

```text
harbor-dt.co.id/devops-apps/zabisa/<image>:<full-source-sha>
```

The project is aligned consistently across Jenkins environment defaults, the
build/scan/push script, the post-push digest verifier, the GitOps renderer and
all sixteen runtime/migration manifest references. Vault paths, Kubernetes
namespace, GitOps directory names and the Go module name remain `zabisa`; they
are unrelated to Harbor authorization and must not be renamed.

## Boundary

The next controlled execution may build, scan and push the new immutable image
set and publish the GitOps overlay. It does not authorize migration, Kubernetes
apply or ArgoCD sync.
