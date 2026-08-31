# Hotfix 0.3.1 — Explicit kubectl Binary Selection

## Problem
Hotfix 0.3 introduced a Kubernetes client/server minor-skew safety guard, but the cluster scripts invoked the literal `kubectl` command. Supplying `KUBECTL=/path/to/kubectl` therefore had no effect and could incorrectly inspect a different binary earlier in `PATH`.

## Fix
Cluster verification/bootstrap scripts now resolve:

```bash
KUBECTL_BIN="${KUBECTL:-kubectl}"
```

and use that executable for every Kubernetes API call.

Affected scripts:
- `verify-cluster-vault-compat.sh`
- `bootstrap-zabisa-platform-prereqs.sh`
- `bootstrap-zabisa-vault-ca.sh`
- optional cluster validation in `apply-hotfix-0.1-0.2.sh`

No Kubernetes object is mutated by applying this source hotfix.

## Usage

```bash
KUBECTL="$HOME/.local/bin/kubectl-zabisa" bash scripts/verify-cluster-vault-compat.sh
```
