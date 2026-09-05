# DT4.5.3 — Sonar New-Code Coverage

Jenkins build `#9` proved that DT4.5.2 removed all ten security hotspots:
Sonar reported zero hotspots and Security Review grade A. The next independent
Quality Gate condition then failed because the newly secured TypeScript code
had no imported test coverage (`0.0%`, required `80.0%`).

DT4.5.3 adds focused unit tests for the Backoffice backend URL boundary and the
mobile donation idempotency-key generator. Both workspace test suites run in
GitHub and Jenkins, both LCOV reports are imported by Sonar, and JavaScript test
files are classified as tests rather than production source.

The 80% new-code coverage condition remains unchanged. No coverage exclusion
is added for the corrected production code.

After GitHub CI succeeds, the controlled runner reuses readiness build `#6`
and starts one new Jenkins delivery build. Migration and Argo CD sync remain
outside this phase.
