# Backoffice Browser E2E Runtime

Zabisa Backoffice Browser E2E uses the installed system Google Chrome binary.

## Artifact policy

- trace: retained on failure
- screenshot: captured on failure
- video: disabled

Video is not required for the current regression suite and would introduce a
Playwright-managed ffmpeg binary dependency even when the browser itself is the
system Chrome installation.

Trace and screenshots remain the primary deterministic failure artifacts.

## Critical regressions

The suite currently proves:
- repeated client navigation through User & Access remains healthy;
- Guardian onboarding exposes the staged create -> link -> approve model;
- Audit Log exposes cross-service audit provenance.

Do not replace these browser checks with curl-only tests.
