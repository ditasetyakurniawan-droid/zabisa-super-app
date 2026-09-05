# ADR-011: Mobile Presentation System

Status: Amended by Phase 3.9.1 physical review

## Context

The functional mobile flow was stable, but the Phase 3.1 sky-blue presentation
needed a stronger Zabisa identity, more consistent controls and an accessible
micro-interaction model. The redesign must not create business or data risk
before the first controlled database migration.

## Decision

The original Sakinah direction was implemented but rejected in physical review.
Adopt the Nawasena semantic design system: cobalt global actions, deep navy
hero surfaces, digital cyan, restrained gold, a stable colour per service,
local icons, an original Quran learner mascot, 48dp minimum controls, unchanged
five-destination navigation and reduced-motion-aware geometric animation.

Implementation is limited to `src/theme`, shared presentational components,
navigation styling and screen layout/style declarations. Existing API calls,
query keys, Zustand state, authentication, validation, deep-link routing,
transaction payloads and navigation order are invariant.

## Consequences

- A shared token change updates the entire application consistently.
- Buttons share one component contract while service actions retain a stable,
  recognizable colour identity.
- Islamic character is visible without delaying interaction or data loading.
- Automated source checks can prohibit changes to logic-bearing mobile files.
- Physical Android and Backoffice acceptance remain mandatory before database
  migration approval.

ADR-006 remains the historical Phase 3.1 decision and is superseded only for
the visual palette and component presentation.
