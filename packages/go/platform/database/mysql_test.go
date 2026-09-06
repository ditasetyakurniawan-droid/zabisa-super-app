package database

import (
	"crypto/rand"
	"crypto/rsa"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"database/sql"
	"encoding/pem"
	"math/big"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestNullableValues(t *testing.T) {
	if NullString("  ") != nil {
		t.Fatal("blank string must map to nil")
	}
	if got := NullString(" value "); got != "value" {
		t.Fatalf("trimmed value = %#v", got)
	}
	if NullableFloat(sql.NullFloat64{}) != nil || NullableInt(sql.NullInt64{}) != nil || NullableTime(sql.NullTime{}) != nil {
		t.Fatal("invalid SQL null values must map to nil")
	}
	now := time.Now().UTC()
	if got := NullableFloat(sql.NullFloat64{Float64: 7.5, Valid: true}); got != 7.5 {
		t.Fatalf("nullable float = %#v", got)
	}
	if got := NullableInt(sql.NullInt64{Int64: 7, Valid: true}); got != int64(7) {
		t.Fatalf("nullable int = %#v", got)
	}
	if got := NullableTime(sql.NullTime{Time: now, Valid: true}); got != now {
		t.Fatalf("nullable time = %#v", got)
	}
}

func writeTestCA(t *testing.T) (string, *x509.Certificate, *rsa.PrivateKey) {
	t.Helper()
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	tmpl := &x509.Certificate{
		SerialNumber:          big.NewInt(1),
		Subject:               pkix.Name{CommonName: "zabisa-test-ca"},
		NotBefore:             time.Now().Add(-time.Hour),
		NotAfter:              time.Now().Add(time.Hour),
		IsCA:                  true,
		BasicConstraintsValid: true,
		KeyUsage:              x509.KeyUsageCertSign | x509.KeyUsageDigitalSignature,
	}
	der, err := x509.CreateCertificate(rand.Reader, tmpl, tmpl, &key.PublicKey, key)
	if err != nil {
		t.Fatal(err)
	}
	cert, err := x509.ParseCertificate(der)
	if err != nil {
		t.Fatal(err)
	}
	p := filepath.Join(t.TempDir(), "ca.pem")
	if err := os.WriteFile(p, pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: der}), 0o400); err != nil {
		t.Fatal(err)
	}
	return p, cert, key
}

func TestVerifyCARejectsUntrustedServer(t *testing.T) {
	caFile, _, _ := writeTestCA(t)
	cfg, err := mysqlTLSConfig(TLSOptions{Mode: TLSVerifyCA, CAFile: caFile})
	if err != nil {
		t.Fatal(err)
	}
	if !cfg.InsecureSkipVerify || cfg.VerifyConnection == nil || cfg.MinVersion != tls.VersionTLS12 {
		t.Fatal("verify-ca TLS config must pin CA, require TLS1.2+, and use explicit chain verification")
	}

	otherCAFile, otherCA, otherKey := writeTestCA(t)
	_ = otherCAFile
	serverTemplate := &x509.Certificate{
		SerialNumber: big.NewInt(2),
		Subject:      pkix.Name{CommonName: "mysql-auto-generated"},
		NotBefore:    time.Now().Add(-time.Hour),
		NotAfter:     time.Now().Add(time.Hour),
		ExtKeyUsage:  []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth},
	}
	serverKey, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	serverDER, err := x509.CreateCertificate(rand.Reader, serverTemplate, otherCA, &serverKey.PublicKey, otherKey)
	if err != nil {
		t.Fatal(err)
	}
	serverCert, err := x509.ParseCertificate(serverDER)
	if err != nil {
		t.Fatal(err)
	}
	if err := cfg.VerifyConnection(tls.ConnectionState{PeerCertificates: []*x509.Certificate{serverCert, otherCA}}); err == nil {
		t.Fatal("verify-ca accepted a server certificate signed by an untrusted CA")
	}
}
