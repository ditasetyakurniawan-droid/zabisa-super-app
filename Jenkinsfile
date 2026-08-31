pipeline {
  agent any
  options { timestamps(); disableConcurrentBuilds() }
  parameters {
    string(name: 'HARBOR_CREDENTIALS_ID', defaultValue: '', description: 'Jenkins username/password credential ID for Harbor push on main')
  }
  environment {
    HARBOR = 'harbor-dt.co.id'
    PROJECT = 'zabisa'
    GO_IMAGE = 'golang:1.26.7-alpine'
    NODE_IMAGE = 'node:22-alpine'
  }
  stages {
    stage('Checkout') {
      steps {
        checkout scm
        sh 'git rev-parse HEAD > .gitsha'
      }
    }
    stage('Go Quality') {
      steps {
        sh '''docker run --rm -v "$PWD:/src" -w /src $GO_IMAGE sh -c 'export PATH=/usr/local/go/bin:$PATH; go version; go mod download; test -z "$(gofmt -l services packages/go)"; go vet ./...; mkdir -p coverage; go test -coverprofile=coverage/go-cover.out ./...' '''
      }
    }
    stage('Node Quality') {
      steps {
        sh '''docker run --rm -v "$PWD:/src" -w /src $NODE_IMAGE sh -c 'npm ci --workspaces --include-workspace-root --no-audit --no-fund && npm run node:lock:verify && npm run lint && npm run typecheck' '''
      }
    }
    stage('Image Pipeline Invariants') {
      steps {
        sh './scripts/verify-image-pipeline.sh'
      }
    }
    stage('SonarQube') {
      steps {
        withSonarQubeEnv('sonar-dt') { sh 'sonar-scanner' }
      }
    }
    stage('Quality Gate') {
      steps {
        timeout(time: 10, unit: 'MINUTES') { waitForQualityGate abortPipeline: true }
      }
    }
    stage('Build + Scan Images') {
      steps {
        sh './scripts/build-images.sh "$(cat .gitsha)" --build-scan'
        archiveArtifacts artifacts: 'build/sbom/*.cdx.json', fingerprint: true
      }
    }
    stage('Push Immutable Images') {
      when { branch 'main' }
      steps {
        script {
          if (!params.HARBOR_CREDENTIALS_ID?.trim()) {
            error('HARBOR_CREDENTIALS_ID must be configured in Jenkins for main-branch Harbor push.')
          }
          withCredentials([usernamePassword(credentialsId: params.HARBOR_CREDENTIALS_ID, usernameVariable: 'HARBOR_USERNAME', passwordVariable: 'HARBOR_PASSWORD')]) {
            sh '''set -eu
              trap 'docker logout "$HARBOR" >/dev/null 2>&1 || true' EXIT
              printf '%s' "$HARBOR_PASSWORD" | docker login "$HARBOR" --username "$HARBOR_USERNAME" --password-stdin
              ./scripts/build-images.sh "$(cat .gitsha)" --push-only
            '''
          }
        }
      }
    }
    stage('Render GitOps Manifests') {
      when { branch 'main' }
      steps {
        sh './scripts/update-gitops.sh "$(cat .gitsha)" build/gitops-rendered'
        archiveArtifacts artifacts: 'build/gitops-rendered/**', fingerprint: true
      }
    }
  }
}
