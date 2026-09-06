package main

import (
	"context"
	"database/sql"
	"testing"

	_ "github.com/go-sql-driver/mysql"
	"github.com/zabisa/platform/packages/go/platform/config"
)

func TestBuildService(t *testing.T) {
	db, err := sql.Open("mysql", "test:secret@tcp(127.0.0.1:1)/test_db")
	if err != nil {
		t.Fatalf("open test database handle: %v", err)
	}
	defer db.Close()

	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	handler, err := buildService(ctx, db, config.Config{
		Service:            "academic-service",
		Environment:        "dt",
		JWTKey:             "012345678901234567890123",
		InternalServiceKey: "012345678901234567890123",
	})
	if err != nil {
		t.Fatalf("build service: %v", err)
	}
	if handler == nil {
		t.Fatal("build service returned a nil handler")
	}
}
