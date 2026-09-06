package database

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"database/sql"
	"errors"
	"fmt"
	"os"
	"strings"
	"time"

	mysql "github.com/go-sql-driver/mysql"
)

func NullString(value string) any {
	if strings.TrimSpace(value) == "" {
		return nil
	}
	return strings.TrimSpace(value)
}

func NullableFloat(value sql.NullFloat64) any {
	if !value.Valid {
		return nil
	}
	return value.Float64
}

func NullableInt(value sql.NullInt64) any {
	if !value.Valid {
		return nil
	}
	return value.Int64
}

func NullableTime(value sql.NullTime) any {
	if !value.Valid {
		return nil
	}
	return value.Time
}

const (
	TLSDisabled       = "disabled"
	TLSVerifyCA       = "verify-ca"
	TLSVerifyIdentity = "verify-identity"
)

type TLSOptions struct {
	Mode       string
	CAFile     string
	ServerName string
}

func Open(ctx context.Context, dsn string, tlsOpts TLSOptions) (*sql.DB, error) {
	cfg, err := mysql.ParseDSN(dsn)
	if err != nil {
		return nil, fmt.Errorf("parse mysql dsn: %w", err)
	}
	if cfg.TLS, err = mysqlTLSConfig(tlsOpts); err != nil {
		return nil, err
	}
	cfg.TLSConfig = ""

	connector, err := mysql.NewConnector(cfg)
	if err != nil {
		return nil, fmt.Errorf("mysql connector: %w", err)
	}
	db := sql.OpenDB(connector)
	db.SetMaxOpenConns(20)
	db.SetMaxIdleConns(10)
	db.SetConnMaxLifetime(30 * time.Minute)
	db.SetConnMaxIdleTime(5 * time.Minute)
	pingCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	if err = db.PingContext(pingCtx); err != nil {
		_ = db.Close()
		return nil, fmt.Errorf("mysql ping: %w", err)
	}
	return db, nil
}

func mysqlTLSConfig(opts TLSOptions) (*tls.Config, error) {
	switch opts.Mode {
	case "", TLSDisabled:
		return nil, nil
	case TLSVerifyCA, TLSVerifyIdentity:
	default:
		return nil, fmt.Errorf("unsupported MySQL TLS mode %q", opts.Mode)
	}

	pem, err := os.ReadFile(opts.CAFile)
	if err != nil {
		return nil, fmt.Errorf("read MySQL CA %q: %w", opts.CAFile, err)
	}
	roots := x509.NewCertPool()
	if ok := roots.AppendCertsFromPEM(pem); !ok {
		return nil, fmt.Errorf("MySQL CA %q contains no parseable certificates", opts.CAFile)
	}

	if opts.Mode == TLSVerifyIdentity {
		if opts.ServerName == "" {
			return nil, errors.New("MySQL TLS verify-identity requires a server name")
		}
		return &tls.Config{
			MinVersion: tls.VersionTLS12,
			RootCAs:    roots,
			ServerName: opts.ServerName,
		}, nil
	}

	// MySQL's auto-generated server certificate does not contain the service DNS
	// identity, so DT currently uses VERIFY_CA semantics: encryption is mandatory
	// and the certificate chain must terminate at the pinned MySQL CA, but hostname
	// matching is intentionally not performed. InsecureSkipVerify disables Go's
	// built-in hostname verification only; VerifyConnection below performs explicit
	// certificate-chain verification against the pinned CA and fails closed.
	return &tls.Config{
		MinVersion:         tls.VersionTLS12,
		RootCAs:            roots,
		InsecureSkipVerify: true, // verified explicitly in VerifyConnection
		VerifyConnection: func(cs tls.ConnectionState) error {
			if len(cs.PeerCertificates) == 0 {
				return errors.New("MySQL TLS peer did not present a certificate")
			}
			intermediates := x509.NewCertPool()
			for _, cert := range cs.PeerCertificates[1:] {
				intermediates.AddCert(cert)
			}
			_, err := cs.PeerCertificates[0].Verify(x509.VerifyOptions{
				Roots:         roots,
				Intermediates: intermediates,
				KeyUsages:     []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth},
			})
			if err != nil {
				return fmt.Errorf("verify MySQL server certificate against pinned CA: %w", err)
			}
			return nil
		},
	}, nil
}
