# ArgoCD

ArgoCD is the deployment authority. Jenkins builds/tests/scans and pushes immutable SHA-tagged images to Harbor, then commits updated tags to the GitOps repository. ArgoCD reconciles Kubernetes. Jenkins must not run imperative `kubectl set image` for production delivery.

DT4.5.7 published source revision
`e1af81dc96d5dc59876f090614e68dc48a32c59f` to GitOps commit `96cef84` with
16 immutable image references across 12 manifests. This is desired-state
evidence only: the Application has not been synced and migration Jobs have not
run. Phase 3.9 physical-device/Backoffice acceptance and the backup/restore gate
must complete before an operator authorizes the first manual sync.
