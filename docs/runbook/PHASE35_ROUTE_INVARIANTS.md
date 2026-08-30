# Phase 3.5 Route Invariants

Phase 3.5 uses exact route-registration checks.

A substring such as:

`/api/v1/admin/donation/campaigns/{id}`

must not be used as an idempotency marker because it is also contained in:

`/api/v1/admin/donation/campaigns/{id}/updates`

The route verifier therefore checks complete registration statements and
requires each critical route exactly once.

This prevents a false-positive installer state where the campaign update
history route exists but the campaign lifecycle PATCH route is absent.
