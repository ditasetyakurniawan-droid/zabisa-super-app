# Hotfix 0.3.7 — API Gateway Readiness Contract

## Why

The API Gateway Deployment probes `/health/ready`, but the gateway previously
served only `/health/live`. Kubernetes therefore received HTTP 404 from every
readiness probe and could not add otherwise healthy gateway Pods to the Service
endpoints.

## Decision

The gateway now exposes two explicit process-health endpoints:

- `GET /health/live` returns `200` with status `ok`;
- `GET /health/ready` returns `200` with status `ready`.

Readiness is intentionally process-local. The gateway is stateless, validates
its required runtime configuration before starting, and every upstream service
owns a database-aware readiness probe. Coupling gateway readiness to every
upstream would turn one bounded-service outage into a gateway-wide outage.

## Regression protection

- `services/api-gateway/main_test.go` verifies status codes, response envelope,
  health state, and content type for both endpoints.
- `scripts/preflight-offline.sh` fails when either source route or either
  Kubernetes probe path is missing.

## Deployment impact

No MySQL schema, migration, Vault secret, RBAC rule, public API route, or mobile
contract changes. Rebuild only the `api-gateway` image and render the immutable
SHA into GitOps before deployment.

## Runtime acceptance

After rollout, both commands must return HTTP 200 and the API Gateway Deployment
must report all desired replicas Ready:

```bash
kubectl -n zabisa-app exec deploy/api-gateway -- wget -qO- http://127.0.0.1:8080/health/live
kubectl -n zabisa-app exec deploy/api-gateway -- wget -qO- http://127.0.0.1:8080/health/ready
kubectl -n zabisa-app rollout status deployment/api-gateway --timeout=180s
```
