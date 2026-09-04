# DT4.3-DT4.4 — Controlled Jenkins development delivery

Status: **SOURCE READY / LIVE EXECUTION PENDING**

## Target

Produce the nine Zabisa application images in the existing Jenkins and Harbor
architecture quickly enough for development review, while retaining immutable
tags, vulnerability evidence and an automatic return to a disabled job.

## Execution

```bash
./scripts/run-zabisa-jenkins-delivery.sh --plan

DT44_CONFIRM=RUN-JENKINS-BUILD-PUSH \
JENKINS_SSH_TARGET=ubuntu@192.168.100.57 \
  ./scripts/run-zabisa-jenkins-delivery.sh --run
```

The controlled runner performs:

1. source and preflight verification;
2. temporary enablement and Multibranch indexing;
3. a default-off quality, private Sonar and Dockerized Trivy readiness build;
4. an explicitly parameterized build/scan/SBOM/push/render build;
5. verification of nine Harbor digest references;
6. return of `zabisa-super-app-v1` to `DISABLED`.

## Evidence gate

DT4.3/DT4.4 is live-complete only when the final output reports both Jenkins
builds successful, nine Harbor digests verified, sixteen GitOps image
references rendered and the parent job disabled. Save the digest TSV and its
SHA-256 for the phase-closing documentation update.

This phase does not run MySQL migration, create application workloads or invoke
ArgoCD sync.
