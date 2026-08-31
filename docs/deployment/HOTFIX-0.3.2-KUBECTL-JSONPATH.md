# Hotfix 0.3.2 — Portable Vault CA Secret Inspection

## Problem

The first `zabisa-app` prerequisite bootstrap created the namespace, per-workload ServiceAccounts and NetworkPolicies, then stopped while inspecting the source `vault-ca` Secret.

The failing expression used Go-template-style map assignment inside kubectl JSONPath:

```text
{range $k,$v := .data}{$k}{"\\n"}{end}
```

kubectl JSONPath does not support that assignment syntax.

## Fix

- Inspect Secret key names with `kubectl -o json | python3`.
- Never print or place Secret values in shell variables.
- Require the source and destination `vault-ca` Secret to contain exactly one non-empty `ca.crt` key.
- Preserve the existing `KUBECTL=/path/to/kubectl` override.
- Keep bootstrap idempotent so it can be safely rerun after a partial first execution.

## Recovery

After applying this hotfix, rerun:

```bash
KUBECTL="$HOME/.local/bin/kubectl-zabisa" bash scripts/bootstrap-zabisa-platform-prereqs.sh test-app
```

Existing Namespace, ServiceAccounts and NetworkPolicies should report `unchanged`; the script then copies and verifies `vault-ca` and completes.
