# ADR-007: Mobile Authentication Navigation and Deep-Link Context

## Status
Accepted for Phase 3.2.

## Context

Authentication was initially implemented inside the Account tab. That was sufficient for foundation validation but retained the main tab bar during login and mixed public navigation with the authentication boundary.

Tahfidz and academic events also generated links containing only a resource ID. A guardian may have more than one linked student, so a deep link must carry enough object context to resolve the authorized student deterministically.

## Decision

1. Login is a root-stack screen outside the bottom tabs.
2. Pressing Account while signed out opens the root Login screen.
3. New private deep links use:

```text
zabisa://guardian/students/{student_id}/tahfidz/{entry_id}
zabisa://guardian/students/{student_id}/academic/{grade_id}
```

4. Mobile continues to parse legacy `zabisa://tahfidz/{id}` and `zabisa://academic/{id}` links.
5. Backend object-level authorization remains authoritative. A deep link never grants access by itself.
6. Android and iOS register only the `zabisa` custom scheme in this phase. Universal/App Links can be introduced later when production domains are finalized.

## Consequences

- Authentication UI is cleaner and less coupled to tabs.
- Multi-child Guardian deep links become deterministic.
- Existing development notifications remain usable.
- A native rebuild is required after URL-scheme registration.
