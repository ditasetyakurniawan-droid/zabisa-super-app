# Phase 3.9.1 — Nawasena Mobile Redesign

## Decision

The physically tested Sakinah design is superseded. Its monochrome controls,
four-column shortcut grid, oversized failure card and arch-heavy treatment did
not meet the intended modern enterprise quality. Nawasena is the new review
candidate; it remains a presentation-only change.

## Brand grounding

The interface reflects Zabisa as a Quran-learning environment that combines
tahfidz, adab/akhlak, Islamic learning and practical life skills. Product copy
is warm, concise and action-oriented: “Ilmu tumbuh. Adab berlabuh.”, “Majelis
Ilmu”, “Jejak Karya”, “Momen Santri”, and “Jalan kebaikan”. These labels do not
change route names, API values or backend-owned content.

## Visual structure

1. Compact greeting and recognizable Zabisa identity.
2. Deep-navy hero with original Quran learner mascot and one concise promise.
3. Two-column service cards with a unique colour, icon, title and plain-language
   category label.
4. Compact inline failure state that does not overpower actual content.
5. Context-coloured Kajian and Donation surfaces.
6. Five unchanged bottom destinations with focused colour capsules.

## Zero-logic proof

`docs/mobile/PHASE3_9_LOGIC_BASELINE.sha256` remains authoritative. The API
client, query keys, authentication/state store, validation, idempotency,
deep-link parsing, navigation types and domain models must continue matching
that checksum manifest. Navigation has exactly five tabs and nine stack
destinations.

## Original mascot asset

`apps/mobile/src/assets/zabisa-quran-mascot.png` is an original generated
project asset. It depicts a young Indonesian student respectfully holding a
closed Quran. The book uses a geometric gold medallion without Arabic text.
The asset is local, requires no network request and is decorative only.

## Physical acceptance

- verify common Android font sizes and a larger accessibility font;
- verify reduced-motion mode;
- verify all eight Home actions and five bottom destinations;
- verify Login, Guardian, Kajian, Donation and Notifications;
- verify loading, empty and compact retry states;
- verify Backoffice independently at `http://localhost:3001`;
- do not approve database migration or ArgoCD sync from this UI phase.
