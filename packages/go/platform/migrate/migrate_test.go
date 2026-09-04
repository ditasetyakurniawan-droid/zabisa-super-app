package migrate

import (
	"crypto/sha256"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"testing/fstest"
)

func TestLoadPlanSortsAndChecksumsExactBytes(t *testing.T) {
	files := fstest.MapFS{
		"migrations/002_second.sql": {Data: []byte("CREATE TABLE IF NOT EXISTS second (id INT);\n")},
		"migrations/001_first.sql":  {Data: []byte("CREATE TABLE IF NOT EXISTS first (id INT);\n")},
		"migrations/README.md":      {Data: []byte("ignored")},
	}

	plan, err := loadPlan(files, "migrations")
	if err != nil {
		t.Fatalf("loadPlan returned error: %v", err)
	}
	if len(plan) != 2 {
		t.Fatalf("plan length = %d, want 2", len(plan))
	}
	if plan[0].name != "001_first.sql" || plan[1].name != "002_second.sql" {
		t.Fatalf("unexpected migration order: %s, %s", plan[0].name, plan[1].name)
	}

	want := sha256.Sum256(files["migrations/001_first.sql"].Data)
	if plan[0].checksum != fmt.Sprintf("%x", want) {
		t.Fatalf("checksum = %s, want %x", plan[0].checksum, want)
	}
}

func TestLoadPlanRejectsEmptyMigrationSet(t *testing.T) {
	files := fstest.MapFS{"migrations/README.md": {Data: []byte("none")}}
	if _, err := loadPlan(files, "migrations"); err == nil {
		t.Fatal("empty migration set was accepted")
	}
}

func TestLoadPlanRejectsEmptySQLFile(t *testing.T) {
	files := fstest.MapFS{"migrations/001_empty.sql": {Data: []byte(" ; \n")}}
	if _, err := loadPlan(files, "migrations"); err == nil {
		t.Fatal("empty SQL migration was accepted")
	}
}

func TestRepositoryMigrationStatementShapes(t *testing.T) {
	paths, err := filepath.Glob("../../../../services/*/migrations/*.sql")
	if err != nil {
		t.Fatalf("glob repository migrations: %v", err)
	}
	if len(paths) != 18 {
		t.Fatalf("repository migration count = %d, want 18", len(paths))
	}

	for _, path := range paths {
		body, err := os.ReadFile(path)
		if err != nil {
			t.Fatalf("read %s: %v", path, err)
		}
		statements := splitStatements(string(body))
		if len(statements) == 0 {
			t.Fatalf("%s contains no statements", path)
		}

		for _, statement := range statements {
			upper := strings.ToUpper(strings.TrimSpace(statement))
			if strings.HasPrefix(upper, "CREATE TABLE IF NOT EXISTS ") {
				continue
			}
			if strings.HasPrefix(upper, "ALTER TABLE ") && len(statements) == 1 {
				continue
			}
			t.Fatalf("%s contains a statement outside the approved migration shapes: %s", path, statement)
		}
	}
}
