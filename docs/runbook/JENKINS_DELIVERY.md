# Jenkins Delivery Runbook

Status: **DT4.5.7 immutable delivery complete; Jenkins disabled**

Verified date: `2026-09-05`

## Purpose

This runbook keeps Zabisa on the existing DT delivery architecture. It prevents
developers from creating an alternate runner, registry path or imperative
cluster deployment.

## Ownership map

| Component | Address or identifier | Responsibility |
|---|---|---|
| GitHub Actions | `Engineering Quality Gate`, `Backoffice Browser E2E` | Remote source, test and browser gates |
| Jenkins Compose | `192.168.100.57`, container `jenkins-server` | Private Sonar and approved delivery stages |
| Jenkins job | `zabisa-super-app-v1` | Zabisa Multibranch Pipeline; currently disabled |
| Existing pattern | `tropical-management-v1` | Proven job structure reused by Zabisa |
| Harbor | `harbor-dt.co.id` / `192.168.100.58` | Immutable application image registry |
| SonarQube | `sonar-dt` / `192.168.100.59:9000` | Private code analysis and quality gate |
| Kubernetes | masters `.51-.53`, workers `.54-.56` | Runtime target after later GitOps approval |
| MySQL | `db-dt` / `192.168.100.70:3306` | External Compose database target |

## Jenkins credential references

Only Jenkins credential identifiers belong in source:

- `github-credentials-id` for SCM access;
- `harbor-cred` for an approved Harbor login/push;
- `github-credentials-id` for SCM and write access to the dedicated Zabisa
  GitOps repository during this development phase;
- the configured `sonar-dt` installation for private Sonar.

Credential values, Jenkins API tokens, Harbor robot passwords, CA private
material and Vault values must never be committed, printed or attached to a
ticket. A Jenkins API token used by an operator is temporary control-plane
authentication; it is not a pipeline credential.

## Locked DT4.2.1 state

The following was proven through Jenkins API read-back:

- authentication succeeded as the existing Jenkins administrator;
- the source config uses `GitHubSCMSource`;
- repository is `ditasetyakurniawan-droid/zabisa-super-app`;
- SCM credential identifier is `github-credentials-id`;
- script path is `Jenkinsfile`;
- automatic triggers are empty;
- `zabisa-super-app-v1` is disabled;
- no indexing/build was requested;
- Docker and Harbor were not touched.

The renderer also retains tested compatibility with a plain `GitSCMSource` and
fails closed for unknown or ambiguous SCM shapes.

## Developer workflow

Before editing:

```bash
git switch main
git pull --ff-only origin main
git status --short --branch
./scripts/verify-dt42-jenkins-alignment.sh
./scripts/preflight-offline.sh
```

For application development, use a feature branch and run the canonical local
quality gate. A source change does not authorize a Jenkins delivery action.

```bash
npm ci --workspaces --include-workspace-root --no-audit --no-fund
make quality
```

Production image references must remain full-Git-SHA tags. Never introduce
`:latest`, mutable base images, manual manifest tag edits or a second registry
path.

The canonical Zabisa repository prefix is:

```text
harbor-dt.co.id/devops-apps/zabisa/<image>
```

Do not collapse it to `devops-apps/<image>` or `zabisa/<image>`.

## Delivery sequence

1. GitHub source and Browser E2E gates pass.
2. DT4.3 explicitly defaults image build, Harbor push and GitOps publication to
   off through `BUILD_IMAGES`, `PUSH_IMAGES` and `RENDER_GITOPS`.
3. An operator approves one Jenkins readiness run for quality, private Sonar
   and Dockerized Trivy only.
4. For the development delivery cycle, a second explicitly parameterized build
   performs the DT4.4 build, scan, SBOM and Harbor push.
5. Jenkins commits the rendered DT overlay to
   `zabisa-super-app-gitops/main` using credential-safe `GIT_ASKPASS`.
6. The runner verifies all nine Harbor digest references and GitOps publication,
   then returns the parent
   job to disabled.
7. Remote Harbor digests and worker/containerd pull are verified.
8. Backup/restore and migration phases remain separate.
9. ArgoCD sync occurs only after reviewed GitOps commit and explicit approval.

## DT4.5.7 completion evidence

- Jenkins delivery `#14`: SUCCESS.
- Application revision: `e1af81dc96d5dc59876f090614e68dc48a32c59f`.
- Harbor: nine tags and nine digest references verified.
- GitOps: commit `96cef84`, 16 image references, 12 manifests.
- Jenkins parent: DISABLED.
- Migration and ArgoCD sync: NOT RUN.

Do not rerun build `#14` merely to validate GitOps. The image set is immutable;
future application source changes require a new full-SHA delivery only after
their source and runtime acceptance gates pass.

Before the next controlled run, reconcile the existing job once:

```bash
DT42_CONFIRM=RECONCILE-DISABLED-ZABISA-JOB \
JENKINS_SSH_TARGET=ubuntu@192.168.100.57 \
  ./scripts/bootstrap-zabisa-jenkins-job.sh --reconcile
```

This keeps only `main` discovery, removes PR discovery traits, clears automatic
triggers and leaves the job disabled. It does not index or start a build.

## Current prohibitions

Outside `scripts/run-zabisa-jenkins-delivery.sh`, do not:

- click `Enable` or `Scan Multibranch Pipeline Now`;
- invoke a Jenkins build endpoint;
- run `docker login`, build, pull or push for Zabisa;
- add `--insecure`, `--tls-verify=false` or `curl -k` to pipeline source;
- create an ad-hoc Jenkins, GitHub or local delivery path;
- run migration Jobs, application Deployments or ArgoCD sync.

## Failure behavior

Stop at the first failed gate. A failure does not authorize retry, rollback,
credential rotation, enabling the job or broadening network/TLS exceptions.
Record the last passing section and the exact sanitized error, then review the
next action.

Authentication errors are interpreted as follows:

- `401`: Jenkins username/API-token pair was rejected;
- authenticated render failure: token is valid, but source config did not match
  the supported fail-closed contract;
- `403`: the authenticated identity lacks the required read/create permission
  or CSRF handling failed.

Never include the API token itself in diagnostic output.
