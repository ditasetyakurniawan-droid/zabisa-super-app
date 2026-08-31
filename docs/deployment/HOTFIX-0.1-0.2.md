# Hotfix 0.1–0.2 — Repository hygiene and DT network baseline

Date: 2026-08-31

## Scope

This hotfix intentionally does not add product features. It makes the locked Phase 3.7.6 application safer to carry forward into the existing DT Kubernetes cluster.

### Hotfix 0.1 — repository hygiene

Generated/local artifacts are not source code and must not be committed or copied into build contexts:

- `node_modules/`
- Android `.gradle/` and `.cxx/`
- `*.tsbuildinfo`
- Playwright/test result folders
- Python `__pycache__/` / `*.pyc`
- local `*.bak*` files

`package.json` and `package-lock.json` remain source-controlled. CI restores JavaScript dependencies using `npm ci`.

### Hotfix 0.2 — Kubernetes DT isolation

The Zabisa namespace is `zabisa-app`.

The namespace enforces the Kubernetes `restricted` Pod Security profile and a default-deny ingress/egress NetworkPolicy baseline. Explicit allows are limited to:

1. CoreDNS on TCP/UDP 53.
2. Namespace-local backend service traffic on TCP 8080–8087.
3. Existing DT MySQL host `192.168.100.70/32` on TCP 3306.
4. API gateway ingress on TCP 8080 only from namespaces explicitly labeled `zabisa.network/ingress-access=true`.

The MySQL IP is infrastructure configuration, not application business source code.

## Intentional exclusions

Vault Agent Injector egress is **not** opened in this hotfix because the existing Vault service namespace/address/labels must be reused precisely rather than guessed. Production FCM/payment/internet egress also remains closed because those production integrations are not active in the current locked baseline.

When Vault integration is patched, add only the exact required egress (normally Vault TCP 8200) and preserve `default-deny`.

## DT preflight checks

Before first apply to the shared cluster, verify:

```bash
kubectl -n kube-system get pods -l k8s-app=kube-dns -o wide
kubectl get namespace --show-labels
kubectl get networkpolicy -A
```

If NodeLocal DNSCache is used, add its exact listener IP to the DT NetworkPolicy instead of allowing broad CIDRs.

For the existing ingress controller, label only its namespace for Zabisa gateway access:

```bash
kubectl label namespace <existing-ingress-namespace> zabisa.network/ingress-access=true --overwrite
```

Do not label unrelated application namespaces.
