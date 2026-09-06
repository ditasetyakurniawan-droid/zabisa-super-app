# DT58 Sonar 75% and Immutable Delivery Lock

Status: **LOCKED / DELIVERY COMPLETE**

Verified: `2026-09-06` (Asia/Jakarta)

## Exact evidence

| Evidence | Value |
|---|---|
| Application/image revision | `eee3284a6989857b6d4332f01d453763ccaf71b2` |
| GitHub Engineering Quality Gate | PASS before Jenkins delivery |
| Jenkins readiness | `#18 SUCCESS`, publication controls off |
| Jenkins delivery | `#19 SUCCESS` |
| Private Sonar | PASS, project-specific New Code coverage gate 75% |
| Harbor | 9 immutable full-SHA tags and digest references verified |
| Digest report | `zabisa-harbor-digests-eee3284a6989857b6d4332f01d453763ccaf71b2.tsv` |
| Digest report SHA-256 | `1bfc8d2ac9d851f46b728b30cecddb6e9287e45c09f2b88c6d9f83af8bff6ec4` |
| GitOps revision | `4fbc8b5db597cbdf73199f8f927eb0ac2cc544c9` |
| GitOps content | 16 image references across 12 manifests |
| Jenkins parent | DISABLED |
| Runner result | `DT58_V133_RC=0` |

## What is complete

- The reviewed application source passed local, GitHub, private Sonar and
  Jenkins quality boundaries.
- The project-specific Sonar Quality Gate requires 75% New Code coverage while
  preserving all non-coverage conditions.
- Coverage exclusions remain narrow and business APIs/screens/services remain
  analyzed.
- Reviewed New Code smells were corrected without weakening reliability,
  security, hotspot or duplication conditions.
- Nine application images were built, scanned, pushed and verified by digest.
- The dedicated GitOps repository was updated and read back at the exact source
  revision.
- The controlled runner returned the Jenkins parent job to DISABLED.

## What is deliberately not complete

- Kubernetes workloads have not been applied.
- MySQL migrations have not run.
- ArgoCD has not synced this GitOps revision.
- Cluster-side image pull and runtime acceptance remain DT5-DT8 work.
- This is not a production go-live declaration.

## Lock rule

The immutable runtime checkpoint is the application/image revision
`eee3284a6989857b6d4332f01d453763ccaf71b2`, paired with GitOps revision
`4fbc8b5db597cbdf73199f8f927eb0ac2cc544c9`. Documentation-only commits after
this checkpoint do not require rebuilding these images and must not rewrite the
recorded source/GitOps pairing.

Recommended annotated tag on the application revision:

```text
dt58-sonar75-delivery-locked-2026-09-06
```

Never move or recreate this tag at another commit. Future application changes
must produce a new full-SHA image set and new GitOps revision after both local
developer gates and GitHub quality gates pass.

## Next authorized phase

Only planning and read-only verification may proceed automatically. DT5 begins
with an encrypted backup plus isolated restore proof. Migration, Kubernetes
apply and ArgoCD sync require their own exact operator approvals as described in
`PHASE-DT5-DT8-CONTROLLED-ROLLOUT.md`.
