#!/usr/bin/env bash

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() {
  echo "[dt42-jenkins] ERROR: $*" >&2
  exit 1
}

for required in \
  Jenkinsfile \
  .github/workflows/ci.yml \
  scripts/bootstrap-zabisa-jenkins-job.sh \
  scripts/jenkins_job_config.py \
  scripts/trivy-docker.sh; do
  [[ -f "$required" ]] || fail "missing $required"
done

grep -Fq "defaultValue: 'harbor-cred'" Jenkinsfile \
  || fail 'Jenkinsfile must reuse existing harbor-cred'
grep -Fq "withSonarQubeEnv('SonarQube')" Jenkinsfile \
  || fail 'Jenkinsfile must reuse existing SonarQube installation'
grep -Fq 'waitForQualityGate abortPipeline: true' Jenkinsfile \
  || fail 'Jenkins Sonar quality gate must remain blocking'
grep -Fq -- '--volumes-from "$HOSTNAME"' Jenkinsfile \
  || fail 'Jenkins Compose workspace sharing is missing'
grep -Fq 'TRIVY_BIN=./scripts/trivy-docker.sh' Jenkinsfile \
  || fail 'Dockerized Trivy is not selected by Jenkins'
grep -Fq 'sonar.typescript.tsconfigPaths=' sonar-project.properties \
  || fail 'Sonar-specific TypeScript configuration is missing'
for sonar_tsconfig in \
  apps/admin-web/tsconfig.sonar.json \
  apps/mobile/tsconfig.sonar.json; do
  grep -Fq '"moduleResolution": "node"' "$sonar_tsconfig" \
    || fail "$sonar_tsconfig must use Sonar-compatible node module resolution"
  if grep -Fq '"extends"' "$sonar_tsconfig"; then
    fail "$sonar_tsconfig must be standalone; the legacy analyzer validates inherited bundler options before overrides"
  fi
  if grep -Fq '"moduleResolution": "bundler"' "$sonar_tsconfig"; then
    fail "$sonar_tsconfig still contains unsupported bundler module resolution"
  fi
done

grep -Fq 'build/jenkins/source-revision' Jenkinsfile \
  || fail 'Jenkins source revision must be stored below ignored build/'
grep -Fq 'build/sonar/report-task.txt' Jenkinsfile \
  || fail 'Sonar task metadata must be stored below ignored build/'
if grep -Eq '(^|[/$"])\.gitsha|WORKSPACE/report-task\.txt' Jenkinsfile; then
  fail 'Jenkinsfile still creates repository-root control artifacts'
fi

grep -Fq 'name: Engineering Quality Gate' .github/workflows/ci.yml \
  || fail 'GitHub source quality gate is missing'
grep -Fq 'run: ./scripts/quality-gate.sh' .github/workflows/ci.yml \
  || fail 'canonical GitHub quality script is missing'
grep -Fq 'name: Backoffice Browser E2E' .github/workflows/ci.yml \
  || fail 'GitHub browser E2E gate is missing'

if grep -Eqi 'docker[[:space:]]+(login|push)|build-images\.sh.*--push' \
  .github/workflows/*.yml 2>/dev/null; then
  fail 'GitHub Actions must not own Harbor login/push'
fi

grep -Fq 'source_job="tropical-management-v1"' scripts/bootstrap-zabisa-jenkins-job.sh \
  || fail 'Jenkins bootstrap must clone the proven existing Multibranch pattern'
grep -Fq 'target_job="zabisa-super-app-v1"' scripts/bootstrap-zabisa-jenkins-job.sh \
  || fail 'Jenkins target job name mismatch'
grep -Fq 'scm_credentials="github-credentials-id"' scripts/bootstrap-zabisa-jenkins-job.sh \
  || fail 'existing GitHub SCM credential ID is not selected'
grep -Fq 'disabled.text = "true"' scripts/jenkins_job_config.py \
  || fail 'new Jenkins job must be created disabled'
grep -Fq 'automatic_triggers=none' scripts/jenkins_job_config.py \
  || fail 'automatic Jenkins job triggers must be cleared'
grep -Fq 'GitHubSCMSource' scripts/jenkins_job_config.py \
  || fail 'actual existing GitHubSCMSource shape is unsupported'
grep -Fq 'GitSCMSource' scripts/jenkins_job_config.py \
  || fail 'GitSCMSource compatibility is unsupported'
grep -Fq 'CREATE-DISABLED-ZABISA-JOB' scripts/bootstrap-zabisa-jenkins-job.sh \
  || fail 'explicit disabled-job creation confirmation is missing'
grep -Fq 'RECONCILE-DISABLED-ZABISA-JOB' scripts/bootstrap-zabisa-jenkins-job.sh \
  || fail 'explicit existing-job reconciliation confirmation is missing'
grep -Fq 'regex.text = "^main$"' scripts/jenkins_job_config.py \
  || fail 'Jenkins SCM discovery is not restricted to main'

if grep -Eqi 'buildWithParameters|/build\?|/build$|/enable$' \
  scripts/bootstrap-zabisa-jenkins-job.sh; then
  fail 'bootstrap must not enable or start a Jenkins build'
fi

PYTHONPATH=scripts python3 -m unittest scripts/test_jenkins_job_config.py

echo '[dt42-jenkins] PASS: GitHub source quality and existing Jenkins Sonar/delivery boundaries are aligned.'
