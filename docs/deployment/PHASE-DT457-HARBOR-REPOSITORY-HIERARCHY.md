# DT4.5.7 — Harbor Repository Hierarchy and Digest Parsing

Status: **COMPLETE**

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

## Completion evidence

- Application revision:
  `e1af81dc96d5dc59876f090614e68dc48a32c59f`.
- Jenkins readiness build: `#6 SUCCESS`.
- Jenkins delivery build: `#14 SUCCESS`.
- SonarQube and Quality Gate: PASS.
- Nine Trivy-scanned images, SBOMs and Harbor digest references: verified.
- Digest report SHA-256:
  `9d5e3ef9c5f5fa3a58a9d565de1913a1d0fb21ed3df468658cfafc31b0d83d87`.
- GitOps publication commit: `6117aff`; verifier correction commit: `96cef84`.
- GitOps source revision: application revision above.
- GitOps render: 16 immutable image references across 12 manifests, PASS.
- Jenkins parent job: returned to DISABLED.

The GitOps repository verifier originally retained the old registry path and
reported zero references after a successful publication. Commit `96cef84`
corrected only that verifier and its documentation; no image rebuild or Harbor
push was required.

Database migration, Kubernetes apply and ArgoCD sync remain NOT RUN. An
incomplete build-13 repository path may remain in Harbor; it is not referenced
by GitOps and its optional cleanup is a separate destructive operation.
