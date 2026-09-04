# Phase 3.8.3 — Browser E2E Dependency Readiness

## Incident

GitHub Actions run `33802952349` passed the Go, Node, mobile, Backoffice, and
quality job. The browser job failed before Playwright ran because the
development seed received `HTTP 502 UPSTREAM_UNAVAILABLE` from the API Gateway
while Identity was still starting.

The Compose startup gate only established API Gateway and Admin Web readiness.
API Gateway readiness is intentionally local to the gateway process, so it did
not prove that Identity had completed its database bootstrap.

## Resolution

The seed now waits at its first admin login, which is the first operation that
requires Identity. The retry contract is deliberately narrow:

- retry transport failures and HTTP `502`, `503`, or `504`;
- use bounded exponential backoff;
- stop after `ZABISA_SEED_READY_TIMEOUT_SECONDS` (default `120` seconds);
- fail immediately for authentication, authorization, validation, and other
  API contract failures.

No arbitrary fixed startup delay is added. The seed remains localhost-only and
continues to write exclusively through application APIs, never directly to
MySQL.

## Regression coverage

`scripts/test_mobile_seed_readiness.py` proves:

- transient upstream errors recover;
- authentication errors are never retried;
- the deadline fails closed;
- the HTTP client classifies retryable status codes explicitly.

The tests run in the canonical local/GitHub quality gate and in an isolated
Python container in Jenkins.

## Scope

This hotfix changes no API endpoint, MySQL schema, Vault policy, Kubernetes
manifest, runtime secret, or deployment topology. It performs no external
mutation during validation.
