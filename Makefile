SHELL := /bin/bash
.PHONY: test lint fmt vet dev compose-up compose-down verify mobile-bootstrap preflight preflight-full images-verify images-plan vault-verify

test:
	go test ./...

lint: fmt vet

fmt:
	@test -z "$$(gofmt -l services packages/go | tee /dev/stderr)"

vet:
	go vet ./...

dev:
	./scripts/run-local.sh

verify:
	./scripts/verify-phase2.sh

compose-up:
	docker compose up -d --build

compose-down:
	docker compose down --remove-orphans

mobile-bootstrap:
	./scripts/bootstrap-mobile-native.sh
	npm ci --workspaces --include-workspace-root --no-audit --no-fund

preflight:
	./scripts/preflight-offline.sh

preflight-full:
	./scripts/preflight-offline.sh --full

images-verify:
	./scripts/verify-image-pipeline.sh

images-plan:
	./scripts/build-images.sh "$$(git rev-parse HEAD)" --plan

vault-verify:
	./scripts/verify-vault-injector.sh
