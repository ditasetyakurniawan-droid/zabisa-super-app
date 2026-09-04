#!/usr/bin/env bash

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() {
  echo "[dt43-control] ERROR: $*" >&2
  exit 1
}

for parameter in BUILD_IMAGES PUSH_IMAGES RENDER_GITOPS; do
  grep -Fq "booleanParam(name: '$parameter', defaultValue: false" Jenkinsfile \
    || fail "$parameter must default to false"
done

grep -Fq "PUSH_IMAGES requires BUILD_IMAGES" Jenkinsfile \
  || fail 'push dependency guard is missing'
grep -Fq "RENDER_GITOPS requires PUSH_IMAGES" Jenkinsfile \
  || fail 'GitOps dependency guard is missing'
grep -Fq "when { expression { return params.BUILD_IMAGES } }" Jenkinsfile \
  || fail 'image build is not guarded by BUILD_IMAGES'
grep -Fq "return params.BUILD_IMAGES && params.PUSH_IMAGES" Jenkinsfile \
  || fail 'Harbor push is not guarded by both build and push approval'
grep -Fq "expression { return params.RENDER_GITOPS }" Jenkinsfile \
  || fail 'GitOps render is not guarded by RENDER_GITOPS'
grep -Fq './scripts/trivy-docker.sh image --download-db-only' Jenkinsfile \
  || fail 'Dockerized Trivy DB readiness proof is missing'

if grep -Eqi 'docker[[:space:]]+(login|push)|buildWithParameters|/enable$' \
  .github/workflows/*.yml 2>/dev/null; then
  fail 'GitHub Actions must not own Jenkins/Harbor delivery'
fi

grep -Fq 'DT44_CONFIRM=RUN-JENKINS-BUILD-PUSH' \
  scripts/run-zabisa-jenkins-delivery.sh \
  || fail 'operator confirmation boundary is missing'
grep -Fq 'BUILD_IMAGES=true' scripts/run-zabisa-jenkins-delivery.sh \
  || fail 'controlled build parameter is missing'
grep -Fq 'PUSH_IMAGES=true' scripts/run-zabisa-jenkins-delivery.sh \
  || fail 'controlled push parameter is missing'
grep -Fq 'RENDER_GITOPS=true' scripts/run-zabisa-jenkins-delivery.sh \
  || fail 'controlled render parameter is missing'
grep -Fq 'disable_parent' scripts/run-zabisa-jenkins-delivery.sh \
  || fail 'Jenkins disable cleanup is missing'

echo '[dt43-control] PASS: default-off readiness and explicit build/push/render controls are consistent.'
