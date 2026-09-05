# DT4.5.7 — Harbor Repository Hierarchy and Digest Parsing

## Build #13 evidence

Build `#13` passed source quality, SonarQube, Quality Gate, Trivy readiness,
and all nine image build/scan/SBOM checks. Harbor login also succeeded. The
first image was pushed to the incomplete repository path
`devops-apps/api-gateway`, after which the delivery stopped because the script
did not extract the returned digest.

Two independent defects were present:

1. Zabisa repositories belong below the existing Harbor project and namespace
   `devops-apps/zabisa`, not directly below `devops-apps`.
2. Docker prints a completed push as `<tag>: digest: sha256:...`; the old parser
   accepted `digest:` only in the first output column and therefore returned an
   empty value.

## Correction

Every producer and consumer now uses:

```text
harbor-dt.co.id/devops-apps/zabisa/<image>:<full-source-sha>
```

The correction covers the Jenkins default, image build/scan/push, remote digest
verification, GitOps rendering, runner read-back, and all sixteen runtime and
migration image references. The digest parser locates the validated
`sha256:<64-hex>` value immediately after `digest:` regardless of its output
column.

An image that may exist at the incomplete build-13 path is not referenced by
GitOps and is not deleted automatically.

## Boundary

The controlled resume may build, scan, push and publish the GitOps overlay. It
does not authorize a database migration, Kubernetes apply, or ArgoCD sync.
