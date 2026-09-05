# Phase DT4.5.1 — Jenkins Artifact and Sonar Compatibility Hotfix

## Evidence

Jenkins readiness build `#6` passed private Sonar, Quality Gate and the
digest-pinned Trivy 0.74.0 database readiness stage. Delivery build `#7`
stopped before the first image build because Jenkins had created `.gitsha` and
`report-task.txt` at repository root. The immutable-image safety check correctly
rejected that dirty worktree.

The same log proved that the legacy private Sonar TypeScript analyzer validates
the inherited application `tsconfig.json` before applying child overrides.
Consequently both Sonar-only configs still exposed unsupported
`moduleResolution=bundler`, and all 70 TypeScript files were skipped.

No image was built or pushed. Harbor, Kubernetes, MySQL and ArgoCD were not
mutated. The controlled runner returned the parent Jenkins job to disabled.

## Corrections

- Store Jenkins source revision at `build/jenkins/source-revision`.
- Store Sonar task metadata at `build/sonar/report-task.txt`.
- Keep the strict dirty-worktree rejection for tracked and untracked source.
- Make both Sonar TypeScript configs standalone with
  `moduleResolution=node`; they no longer extend application configs that use
  `bundler`.
- Fail offline verification if root-level Jenkins artifacts or inherited Sonar
  configs return.
- Add a resume mode that verifies successful readiness build `#6` and starts
  only one new delivery build. The new delivery still runs all source, Sonar,
  Quality Gate and Trivy stages before building or pushing an image.

## Boundary

This source hotfix does not itself enable Jenkins, build or push images, run a
database migration, apply an ArgoCD Application, or sync workloads.
