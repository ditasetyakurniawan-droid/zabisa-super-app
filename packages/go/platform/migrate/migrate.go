package migrate

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"errors"
	"fmt"
	"io/fs"
	"sort"
	"strings"
	"time"
)

const lockWaitSeconds = 30

type plannedMigration struct {
	name       string
	checksum   string
	statements []string
}

// Apply executes embedded migrations in lexical order on one pinned MySQL
// connection. The advisory lock prevents two migrators from changing the same
// schema concurrently, and the checksum makes changed historical SQL fail
// closed.
func Apply(ctx context.Context, db *sql.DB, migrationsFS fs.FS, dir string) (err error) {
	plan, err := loadPlan(migrationsFS, dir)
	if err != nil {
		return err
	}

	conn, err := db.Conn(ctx)
	if err != nil {
		return fmt.Errorf("pin migration connection: %w", err)
	}
	defer conn.Close()

	var databaseName string
	if err := conn.QueryRowContext(ctx, `SELECT DATABASE()`).Scan(&databaseName); err != nil {
		return fmt.Errorf("resolve migration database: %w", err)
	}
	if strings.TrimSpace(databaseName) == "" {
		return errors.New("migration database is empty")
	}

	lockName := "zabisa:migrate:" + databaseName
	if len(lockName) > 64 {
		lockName = lockName[:64]
	}

	var lockAcquired sql.NullInt64
	if err := conn.QueryRowContext(ctx, `SELECT GET_LOCK(?, ?)`, lockName, lockWaitSeconds).Scan(&lockAcquired); err != nil {
		return fmt.Errorf("acquire migration advisory lock: %w", err)
	}
	if !lockAcquired.Valid || lockAcquired.Int64 != 1 {
		return fmt.Errorf("migration advisory lock unavailable after %d seconds", lockWaitSeconds)
	}

	defer func() {
		releaseCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		var released sql.NullInt64
		releaseErr := conn.QueryRowContext(releaseCtx, `SELECT RELEASE_LOCK(?)`, lockName).Scan(&released)
		if releaseErr != nil {
			releaseErr = fmt.Errorf("release migration advisory lock: %w", releaseErr)
		} else if !released.Valid || released.Int64 != 1 {
			releaseErr = errors.New("release migration advisory lock: lock was not owned")
		}
		if err == nil && releaseErr != nil {
			err = releaseErr
		}
	}()

	if err := ensureTrackingTable(ctx, conn, databaseName); err != nil {
		return err
	}

	for _, migration := range plan {
		var storedChecksum string
		scanErr := conn.QueryRowContext(ctx,
			`SELECT checksum FROM schema_migrations WHERE version=?`, migration.name,
		).Scan(&storedChecksum)

		switch {
		case scanErr == nil:
			if storedChecksum != migration.checksum {
				return fmt.Errorf("migration checksum drift for %s: database=%s source=%s", migration.name, storedChecksum, migration.checksum)
			}
			continue
		case !errors.Is(scanErr, sql.ErrNoRows):
			return fmt.Errorf("read migration state for %s: %w", migration.name, scanErr)
		}

		// MySQL DDL can commit implicitly, so this intentionally does not claim
		// transaction rollback semantics. Repository tests constrain every file
		// to reviewed statement shapes and reject multi-statement ALTER files.
		for _, statement := range migration.statements {
			if _, err := conn.ExecContext(ctx, statement); err != nil {
				return fmt.Errorf("migration %s: %w", migration.name, err)
			}
		}

		if _, err := conn.ExecContext(ctx,
			`INSERT INTO schema_migrations(version, checksum) VALUES (?, ?)`,
			migration.name, migration.checksum,
		); err != nil {
			return fmt.Errorf("record migration %s: %w", migration.name, err)
		}
	}

	return nil
}

func ensureTrackingTable(ctx context.Context, conn *sql.Conn, databaseName string) error {
	if _, err := conn.ExecContext(ctx, `CREATE TABLE IF NOT EXISTS schema_migrations (version VARCHAR(255) PRIMARY KEY, checksum CHAR(64) NOT NULL, applied_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6))`); err != nil {
		return fmt.Errorf("create migrations table: %w", err)
	}

	var checksumColumns int
	if err := conn.QueryRowContext(ctx, `SELECT COUNT(*) FROM information_schema.columns WHERE table_schema=? AND table_name='schema_migrations' AND column_name='checksum'`, databaseName).Scan(&checksumColumns); err != nil {
		return fmt.Errorf("inspect migration checksum column: %w", err)
	}
	if checksumColumns > 0 {
		return nil
	}

	var rows int
	if err := conn.QueryRowContext(ctx, `SELECT COUNT(*) FROM schema_migrations`).Scan(&rows); err != nil {
		return fmt.Errorf("count legacy migration records: %w", err)
	}
	if rows > 0 {
		return fmt.Errorf("schema_migrations has %d legacy records without checksums; explicit operator baselining is required", rows)
	}

	if _, err := conn.ExecContext(ctx, `ALTER TABLE schema_migrations ADD COLUMN checksum CHAR(64) NOT NULL`); err != nil {
		return fmt.Errorf("add migration checksum column: %w", err)
	}
	return nil
}

func loadPlan(migrationsFS fs.FS, dir string) ([]plannedMigration, error) {
	entries, err := fs.ReadDir(migrationsFS, dir)
	if err != nil {
		return nil, fmt.Errorf("read migration directory: %w", err)
	}

	var names []string
	for _, entry := range entries {
		if !entry.IsDir() && strings.HasSuffix(entry.Name(), ".sql") {
			names = append(names, entry.Name())
		}
	}
	if len(names) == 0 {
		return nil, errors.New("migration directory contains no SQL files")
	}
	sort.Strings(names)

	plan := make([]plannedMigration, 0, len(names))
	for _, name := range names {
		body, err := fs.ReadFile(migrationsFS, dir+"/"+name)
		if err != nil {
			return nil, fmt.Errorf("read migration %s: %w", name, err)
		}

		statements := splitStatements(string(body))
		if len(statements) == 0 {
			return nil, fmt.Errorf("migration %s contains no SQL statements", name)
		}

		digest := sha256.Sum256(body)
		plan = append(plan, plannedMigration{
			name:       name,
			checksum:   fmt.Sprintf("%x", digest),
			statements: statements,
		})
	}
	return plan, nil
}

func splitStatements(body string) []string {
	var statements []string
	for _, statement := range strings.Split(body, ";") {
		statement = strings.TrimSpace(statement)
		if statement != "" {
			statements = append(statements, statement)
		}
	}
	return statements
}
