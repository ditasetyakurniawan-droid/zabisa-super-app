# DT4.5.4 — Trivy Evidence and Delivery Resume

## Live evidence

Jenkins build `#10` completed checkout, source quality, private SonarQube,
Quality Gate and Dockerized Trivy readiness. SonarQube passed with 96.2% new-code
coverage, zero new bugs, vulnerabilities and security hotspots, and zero new-code
duplication.

All nine immutable images were built. The delivery then stopped while scanning
the first image because Trivy returned its policy exit code while JSON output was
redirected to the workspace. The stage aborted before the JSON could be archived,
and the mandatory cleanup removed the workspace and local images. Harbor push and
GitOps publication were therefore not reached.

Closing the operator terminal did not abort Jenkins build `#10`; Jenkins ran it
to completion. It could, however, interrupt the local controller before its final
parent-job reconciliation.

## Corrected policy and evidence handling

DT4.5.4 separates evidence collection from the blocking decision:

- every image receives a complete HIGH/CRITICAL vulnerability JSON report;
- every image receives a CycloneDX SBOM and immutable scan attestation;
- every image is evaluated even when an earlier image fails policy;
- the blocking policy rejects HIGH/CRITICAL findings only when Trivy reports an
  available fixed version;
- unfixed findings remain visible in archived evidence and may be reassessed when
  a base image or dependency update becomes available;
- scan/SBOM evidence is archived from the pipeline `post` section before cleanup,
  including on a failed stage;
- the controlled runner repairs an enabled parent job left by an interrupted
  operator terminal before starting the next run.

This does not suppress findings or weaken severity. It distinguishes a fixable
delivery blocker from an upstream finding for which no remediation artifact
exists yet. Harbor remains a second post-push scan layer; Jenkins remains the
pre-push enforcement point.

## Scope boundary

The next controlled execution may build, scan, push the nine images and publish
the GitOps overlay. It does not authorize database migration, Kubernetes apply,
or ArgoCD sync.
