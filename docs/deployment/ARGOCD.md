# ArgoCD

ArgoCD is the deployment authority. Jenkins builds/tests/scans and pushes immutable SHA-tagged images to Harbor, then commits updated tags to the GitOps repository. ArgoCD reconciles Kubernetes. Jenkins must not run imperative `kubectl set image` for production delivery.
