# ADR-011: Mobile Sakinah Presentation System

Status: Accepted for Phase 3.9

## Context

The functional mobile flow was stable, but the Phase 3.1 sky-blue presentation
needed a stronger Zabisa identity, more consistent controls and an accessible
micro-interaction model. The redesign must not create business or data risk
before the first controlled database migration.

## Decision

Adopt the Sakinah semantic design system: emerald action color, warm ivory
canvas, restrained gold ornament, local icons, 48dp minimum controls, floating
five-destination navigation and reduced-motion-aware geometric animation.

Implementation is limited to `src/theme`, shared presentational components,
navigation styling and screen layout/style declarations. Existing API calls,
query keys, Zustand state, authentication, validation, deep-link routing,
transaction payloads and navigation order are invariant.

## Consequences

- A shared token change updates the entire application consistently.
- Buttons have one recognizable brand treatment across screens.
- Islamic character is visible without delaying interaction or data loading.
- Automated source checks can prohibit changes to logic-bearing mobile files.
- Physical Android and Backoffice acceptance remain mandatory before database
  migration approval.

ADR-006 remains the historical Phase 3.1 decision and is superseded only for
the visual palette and component presentation.
