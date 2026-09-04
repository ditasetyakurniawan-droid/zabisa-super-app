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
    PYTHON_IMAGE = 'python:3.13-alpine'
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
        sh '''docker run --rm -v "$PWD:/src" -w /src $GO_IMAGE sh -c '
          set -eu
          export PATH=/usr/local/go/bin:$PATH
          export GOTOOLCHAIN=local
          go version
          go mod download
          test -z "$(gofmt -l services packages/go)"
          go vet ./packages/go/... ./services/...
          mkdir -p coverage
          if ! go test -json -count=1 -covermode=atomic -coverpkg=github.com/zabisa/platform/packages/go/...,github.com/zabisa/platform/services/... -coverprofile=coverage/go-cover.out ./packages/go/... ./services/... > coverage/go-test-report.json; then
            tail -n 200 coverage/go-test-report.json
            exit 1
          fi
          go tool cover -func=coverage/go-cover.out | tail -n 1
        ' '''
      }
    }
    stage('Node Quality') {
      steps {
        sh '''docker run --rm -v "$PWD:/src" -w /src $NODE_IMAGE sh -c '
          set -eu
          export CI=true
          export NEXT_TELEMETRY_DISABLED=1
          npm ci --workspaces --include-workspace-root --no-audit --no-fund
          npm run node:lock:verify
          npm run lint --workspace=@zabisa/admin-web -- --max-warnings=0
          npm run lint --workspace=@zabisa/mobile -- --max-warnings=0
          npm run typecheck --workspaces --if-present
          npm run test --workspace=@zabisa/mobile
          npm run build --workspace=@zabisa/admin-web
          npm run audit:production
        ' '''
      }
    }
    stage('Seed Readiness Quality') {
      steps {
        sh '''docker run --rm -v "$PWD:/src" -w /src $PYTHON_IMAGE sh -c '
          set -eu
          python3 -m py_compile scripts/mobile-seed-demo-all.py scripts/test_mobile_seed_readiness.py
          python3 -m unittest discover -s scripts -p "test_*.py"
        ' '''
      }
    }
    stage('Secret Hygiene') {
      steps {
        sh './scripts/verify-secret-hygiene.sh'
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
