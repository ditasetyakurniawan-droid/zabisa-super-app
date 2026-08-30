pipeline {
  agent any
  options { timestamps(); disableConcurrentBuilds() }
  environment { HARBOR = 'harbor-dt.co.id'; PROJECT = 'zabisa'; GO_IMAGE = 'golang:1.26.7-alpine'; NODE_IMAGE = 'node:22-alpine' }
  stages {
    stage('Checkout') { steps { checkout scm; sh 'git rev-parse --short=12 HEAD > .gitsha' } }
    stage('Go Quality') { steps { sh '''docker run --rm -v "$PWD:/src" -w /src $GO_IMAGE sh -c 'export PATH=/usr/local/go/bin:$PATH; go version; go mod download; test -z "$(gofmt -l services packages/go)"; go vet ./...; mkdir -p coverage; go test -coverprofile=coverage/go-cover.out ./...' ''' } }
    stage('Node Quality') { steps { sh '''docker run --rm -v "$PWD:/src" -w /src $NODE_IMAGE sh -c 'npm install --workspaces --include-workspace-root && npm run lint && npm run typecheck' ''' } }
    stage('SonarQube') { steps { withSonarQubeEnv('sonar-dt') { sh 'sonar-scanner' } } }
    stage('Quality Gate') { steps { timeout(time: 10, unit: 'MINUTES') { waitForQualityGate abortPipeline: true } } }
    stage('Build Images') { steps { sh './scripts/build-images.sh "$(cat .gitsha)"' } }
    stage('GitOps Update') { when { branch 'main' }; steps { sh './scripts/update-gitops.sh "$(cat .gitsha)"' } }
  }
}
