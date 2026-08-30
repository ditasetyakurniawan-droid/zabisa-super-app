SHELL := /bin/bash
.PHONY: test lint fmt vet dev compose-up compose-down verify mobile-bootstrap

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
	npm install
