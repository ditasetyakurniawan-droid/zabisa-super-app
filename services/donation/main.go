package main

import (
	"context"
	"database/sql"
	"embed"
	"github.com/zabisa/platform/packages/go/platform/auditx"
	"github.com/zabisa/platform/packages/go/platform/auth"
	"github.com/zabisa/platform/packages/go/platform/authz"
	"github.com/zabisa/platform/packages/go/platform/config"
	"github.com/zabisa/platform/packages/go/platform/database"
	"github.com/zabisa/platform/packages/go/platform/health"
	"github.com/zabisa/platform/packages/go/platform/httpx"
	"github.com/zabisa/platform/packages/go/platform/migrate"
	"github.com/zabisa/platform/packages/go/platform/outbox"
	"github.com/zabisa/platform/packages/go/platform/router"
	"github.com/zabisa/platform/packages/go/platform/server"
	"log/slog"
	"net/http"
	"os"
	"strings"
	"time"
)

//go:embed migrations/*.sql
var migrationFS embed.FS

type app struct {
	db  *sql.DB
	cfg config.Config
}

func (a *app) claims(r *http.Request) (auth.Claims, error) {
	raw := strings.TrimSpace(strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer "))
	return auth.Verify(a.cfg.JWTKey, raw)
}

type campaignIn struct {
	Name         string     `json:"name"`
	Slug         string     `json:"slug"`
	Description  string     `json:"description"`
	Category     string     `json:"category"`
	TargetAmount *float64   `json:"target_amount"`
	CoverURL     string     `json:"cover_url"`
	Deadline     *time.Time `json:"deadline"`
}
type paymentAccountIn struct {
	MethodCode    string `json:"method_code"`
	DisplayName   string `json:"display_name"`
	BankName      string `json:"bank_name"`
	AccountNumber string `json:"account_number"`
	AccountHolder string `json:"account_holder"`
	Instructions  string `json:"instructions"`
}

type proofIn struct {
	ObjectKey string `json:"object_key"`
}

type donationIn struct {
	CampaignID    string  `json:"campaign_id"`
	DonorName     string  `json:"donor_name"`
	DonorEmail    string  `json:"donor_email"`
	Anonymous     bool    `json:"anonymous"`
	Message       string  `json:"message"`
	Amount        float64 `json:"amount"`
	PaymentMethod string  `json:"payment_method"`
}

func main() {
	cfg := config.Load("donation-service", "donation_db", 8086)
	db, err := database.Open(context.Background(), cfg.DSN())
	if err != nil {
		panic(err)
	}
	defer db.Close()
	if err = migrate.Apply(context.Background(), db, migrationFS, "migrations"); err != nil {
		panic(err)
	}
	a := &app{db, cfg}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go outbox.Worker{DB: db, AuditEndpoint: envURL("AUDIT_SERVICE_URL", "http://identity:8081/internal/v1/audit-events"), InternalKey: cfg.InternalServiceKey, Service: cfg.Service}.Run(ctx)
	if cfg.Environment == "local" {
		if err = a.seedLocal(context.Background()); err != nil {
			slog.Error("seed", "error", err)
			os.Exit(1)
		}
	}
	rt := router.New()
	rt.Handle("GET", "/health/live", health.Live)
	rt.Handle("GET", "/health/ready", health.Ready(db))
	rt.Handle("GET", "/api/v1/donation/campaigns", a.listCampaigns)
	rt.Handle("GET", "/api/v1/donation/payment-methods", a.listPaymentMethods)
	rt.Handle("POST", "/api/v1/admin/donation/payment-methods", a.requirePermission(authz.DonationWrite, a.createPaymentMethod))
	rt.Handle("GET", "/api/v1/admin/donation/payment-methods", a.requirePermission(authz.DonationRead, a.listPaymentMethodsAdmin))
	rt.Handle("PATCH", "/api/v1/admin/donation/payment-methods/{id}", a.requirePermission(authz.DonationWrite, a.updatePaymentMethod))
	rt.Handle("POST", "/api/v1/admin/donation/campaigns", a.requirePermission(authz.DonationWrite, a.createCampaign))
	rt.Handle("GET", "/api/v1/admin/donation/campaigns", a.requirePermission(authz.DonationRead, a.listCampaignsAdmin))
	rt.Handle("PATCH", "/api/v1/admin/donation/campaigns/{id}", a.requirePermission(authz.DonationWrite, a.updateCampaign))
	rt.Handle("GET", "/api/v1/admin/donations", a.requirePermission(authz.DonationRead, a.listDonationsAdmin))
	rt.Handle("POST", "/api/v1/donations", a.createDonation)
	rt.Handle("GET", "/api/v1/donations/history", a.listDonationHistory)
	rt.Handle("GET", "/api/v1/donations/{id}", a.getDonation)
	rt.Handle("GET", "/api/v1/donation/campaigns/{id}/updates", a.listCampaignUpdates)
	rt.Handle("POST", "/api/v1/admin/donation/campaigns/{id}/updates", a.requirePermission(authz.DonationWrite, a.createCampaignUpdate))
	rt.Handle("POST", "/api/v1/donations/{id}/proof", a.attachProof)
	rt.Handle("PATCH", "/api/v1/admin/donations/{id}/verify", a.requirePermission(authz.DonationVerify, a.verifyDonation))
	if err = server.Run(cfg.Port, httpx.Middleware(cfg.Service, cfg.AllowedOrigins, rt)); err != nil {
		slog.Error("server", "error", err)
		os.Exit(1)
	}
}
func (a *app) requirePermission(permission authz.Permission, h router.HandlerFunc) router.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request, p map[string]string) {
		c, err := a.claims(r)
		if err != nil {
			httpx.Fail(w, r, 401, "UNAUTHORIZED", "Authentication required")
			return
		}
		if !authz.Has(c.Role, permission) {
			httpx.Fail(w, r, 403, "FORBIDDEN", "Insufficient permission")
			return
		}
		h(w, r, p)
	}
}
func (a *app) listCampaigns(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	rows, err := a.db.QueryContext(r.Context(), `SELECT id,name,slug,description,category,target_amount,collected_amount,cover_url,deadline,status FROM campaigns WHERE status='ACTIVE' ORDER BY created_at DESC LIMIT 100`)
	if err != nil {
		httpx.Fail(w, r, 500, "QUERY_FAILED", "Could not load campaigns")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id, name, slug, desc, cat, status string
		var target sql.NullFloat64
		var collected float64
		var cover sql.NullString
		var deadline sql.NullTime
		if rows.Scan(&id, &name, &slug, &desc, &cat, &target, &collected, &cover, &deadline, &status) == nil {
			out = append(out, map[string]any{"id": id, "name": name, "slug": slug, "description": desc, "category": cat, "target_amount": nf(target), "collected_amount": collected, "cover_url": cover.String, "deadline": nt(deadline), "status": status})
		}
	}
	httpx.JSON(w, 200, out)
}
func (a *app) createCampaign(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	raw := strings.TrimSpace(strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer "))
	actor, _ := auth.Verify(a.cfg.JWTKey, raw)
	var in campaignIn
	if !httpx.Decode(w, r, &in) {
		return
	}
	if in.Name == "" || in.Slug == "" || in.Description == "" || in.Category == "" {
		httpx.Fail(w, r, 400, "VALIDATION", "Campaign fields are required")
		return
	}
	id := httpx.NewID()
	tx, err := a.db.BeginTx(r.Context(), nil)
	if err != nil {
		httpx.Fail(w, r, 500, "TX_FAILED", "Could not create campaign")
		return
	}
	defer tx.Rollback()
	if _, err = tx.ExecContext(r.Context(), `INSERT INTO campaigns(id,name,slug,description,category,target_amount,cover_url,deadline) VALUES(?,?,?,?,?,?,?,?)`, id, in.Name, in.Slug, in.Description, in.Category, in.TargetAmount, n(in.CoverURL), in.Deadline); err != nil {
		httpx.Fail(w, r, 409, "CREATE_FAILED", "Could not create campaign")
		return
	}
	after := map[string]any{"name": in.Name, "slug": in.Slug, "category": in.Category, "target_amount": in.TargetAmount, "status": "ACTIVE"}
	if err = auditx.Add(r.Context(), tx, auditx.FromRequest(r, actor.Sub, "CAMPAIGN_CREATED", "campaign", id, nil, after)); err != nil {
		httpx.Fail(w, r, 500, "AUDIT_ENQUEUE_FAILED", "Could not audit campaign")
		return
	}
	if err = tx.Commit(); err != nil {
		httpx.Fail(w, r, 500, "COMMIT_FAILED", "Could not create campaign")
		return
	}
	httpx.JSON(w, 201, map[string]string{"id": id})
}
func (a *app) createDonation(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	key := strings.TrimSpace(r.Header.Get("Idempotency-Key"))
	if key == "" {
		httpx.Fail(w, r, 400, "IDEMPOTENCY_REQUIRED", "Idempotency-Key header is required")
		return
	}
	var in donationIn
	if !httpx.Decode(w, r, &in) {
		return
	}
	if in.CampaignID == "" || in.Amount <= 0 || in.PaymentMethod == "" {
		httpx.Fail(w, r, 400, "VALIDATION", "campaign_id, positive amount and payment_method are required")
		return
	}
	var methodExists int
	if err := a.db.QueryRowContext(r.Context(), `SELECT COUNT(*) FROM payment_accounts WHERE method_code=? AND active=TRUE`, in.PaymentMethod).Scan(&methodExists); err != nil || methodExists == 0 {
		httpx.Fail(w, r, 400, "INVALID_PAYMENT_METHOD", "Payment method is not available")
		return
	}
	var existing string
	err := a.db.QueryRowContext(r.Context(), `SELECT id FROM donations WHERE idempotency_key=?`, key).Scan(&existing)
	if err == nil {
		httpx.JSON(w, 200, map[string]any{"id": existing, "idempotent_replay": true})
		return
	}
	id := httpx.NewID()
	var donorUserID any
	if raw := strings.TrimSpace(strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")); raw != "" {
		if c, verifyErr := auth.Verify(a.cfg.JWTKey, raw); verifyErr == nil {
			donorUserID = c.Sub
		}
	}
	_, err = a.db.ExecContext(r.Context(), `INSERT INTO donations(id,campaign_id,donor_user_id,donor_name,donor_email,anonymous,message,amount,payment_method,idempotency_key) VALUES(?,?,?,?,?,?,?,?,?,?)`, id, in.CampaignID, donorUserID, n(in.DonorName), n(in.DonorEmail), in.Anonymous, n(in.Message), in.Amount, in.PaymentMethod, key)
	if err != nil {
		httpx.Fail(w, r, 409, "CREATE_FAILED", "Could not create donation")
		return
	}
	httpx.JSON(w, 201, map[string]any{"id": id, "status": "WAITING_PAYMENT", "payment_method": in.PaymentMethod})
}
func (a *app) getDonation(w http.ResponseWriter, r *http.Request, p map[string]string) {
	var id, campaign, status, method string
	var amount float64
	var created time.Time
	err := a.db.QueryRowContext(r.Context(), `SELECT id,campaign_id,amount,status,payment_method,created_at FROM donations WHERE id=?`, p["id"]).Scan(&id, &campaign, &amount, &status, &method, &created)
	if err == sql.ErrNoRows {
		httpx.Fail(w, r, 404, "NOT_FOUND", "Donation not found")
		return
	}
	if err != nil {
		httpx.Fail(w, r, 500, "QUERY_FAILED", "Could not load donation")
		return
	}
	httpx.JSON(w, 200, map[string]any{"id": id, "campaign_id": campaign, "amount": amount, "status": status, "payment_method": method, "created_at": created})
}
func (a *app) verifyDonation(w http.ResponseWriter, r *http.Request, p map[string]string) {
	tx, err := a.db.BeginTx(r.Context(), nil)
	if err != nil {
		httpx.Fail(w, r, 500, "TX_FAILED", "Could not begin verification")
		return
	}
	defer tx.Rollback()
	var campaign string
	var amount float64
	var status string
	if err = tx.QueryRowContext(r.Context(), `SELECT campaign_id,amount,status FROM donations WHERE id=? FOR UPDATE`, p["id"]).Scan(&campaign, &amount, &status); err != nil {
		httpx.Fail(w, r, 404, "NOT_FOUND", "Donation not found")
		return
	}
	if status == "PAID" {
		httpx.JSON(w, 200, map[string]string{"status": "PAID"})
		return
	}
	if status != "WAITING_PAYMENT" && status != "PENDING" {
		httpx.Fail(w, r, 409, "INVALID_STATE", "Donation cannot be verified from current state")
		return
	}
	if _, err = tx.ExecContext(r.Context(), `UPDATE donations SET status='PAID' WHERE id=?`, p["id"]); err != nil {
		httpx.Fail(w, r, 500, "UPDATE_FAILED", "Could not verify donation")
		return
	}
	if _, err = tx.ExecContext(r.Context(), `UPDATE campaigns SET collected_amount=collected_amount+? WHERE id=?`, amount, campaign); err != nil {
		httpx.Fail(w, r, 500, "UPDATE_FAILED", "Could not update campaign")
		return
	}
	raw := strings.TrimSpace(strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer "))
	actor, _ := auth.Verify(a.cfg.JWTKey, raw)
	if err = auditx.Add(r.Context(), tx, auditx.FromRequest(r, actor.Sub, "PAYMENT_VERIFIED", "donation", p["id"], map[string]any{"status": status, "campaign_id": campaign, "amount": amount}, map[string]any{"status": "PAID", "campaign_id": campaign, "amount": amount})); err != nil {
		httpx.Fail(w, r, 500, "AUDIT_ENQUEUE_FAILED", "Could not audit payment verification")
		return
	}
	if err = tx.Commit(); err != nil {
		httpx.Fail(w, r, 500, "COMMIT_FAILED", "Could not commit verification")
		return
	}
	httpx.JSON(w, 200, map[string]string{"status": "PAID"})
}
func n(v string) any {
	if strings.TrimSpace(v) == "" {
		return nil
	}
	return strings.TrimSpace(v)
}
func nf(v sql.NullFloat64) any {
	if !v.Valid {
		return nil
	}
	return v.Float64
}
func nt(v sql.NullTime) any {
	if !v.Valid {
		return nil
	}
	return v.Time
}

func (a *app) listPaymentMethods(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	rows, err := a.db.QueryContext(r.Context(), `SELECT method_code,display_name,bank_name,account_number,account_holder,instructions FROM payment_accounts WHERE active=TRUE ORDER BY display_name`)
	if err != nil {
		httpx.Fail(w, r, 500, "QUERY_FAILED", "Could not load payment methods")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var code, name string
		var bank, number, holder, instructions sql.NullString
		if rows.Scan(&code, &name, &bank, &number, &holder, &instructions) == nil {
			out = append(out, map[string]any{"method_code": code, "display_name": name, "bank_name": bank.String, "account_number": number.String, "account_holder": holder.String, "instructions": instructions.String})
		}
	}
	httpx.JSON(w, 200, out)
}
func (a *app) createPaymentMethod(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	raw := strings.TrimSpace(strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer "))
	actor, _ := auth.Verify(a.cfg.JWTKey, raw)
	var in paymentAccountIn
	if !httpx.Decode(w, r, &in) {
		return
	}
	in.MethodCode = strings.TrimSpace(in.MethodCode)
	in.DisplayName = strings.TrimSpace(in.DisplayName)
	if in.MethodCode == "" || in.DisplayName == "" {
		httpx.Fail(w, r, 400, "VALIDATION", "method_code and display_name are required")
		return
	}
	id := httpx.NewID()
	tx, err := a.db.BeginTx(r.Context(), nil)
	if err != nil {
		httpx.Fail(w, r, 500, "TX_FAILED", "Could not create payment method")
		return
	}
	defer tx.Rollback()
	if _, err = tx.ExecContext(r.Context(), `INSERT INTO payment_accounts(id,method_code,display_name,bank_name,account_number,account_holder,instructions) VALUES(?,?,?,?,?,?,?)`, id, in.MethodCode, in.DisplayName, n(in.BankName), n(in.AccountNumber), n(in.AccountHolder), n(in.Instructions)); err != nil {
		httpx.Fail(w, r, 409, "CREATE_FAILED", "Could not create payment method")
		return
	}
	after := map[string]any{"method_code": in.MethodCode, "display_name": in.DisplayName, "active": true}
	if err = auditx.Add(r.Context(), tx, auditx.FromRequest(r, actor.Sub, "PAYMENT_METHOD_CREATED", "payment_method", id, nil, after)); err != nil {
		httpx.Fail(w, r, 500, "AUDIT_ENQUEUE_FAILED", "Could not audit payment method creation")
		return
	}
	if err = tx.Commit(); err != nil {
		httpx.Fail(w, r, 500, "COMMIT_FAILED", "Could not create payment method")
		return
	}
	httpx.JSON(w, 201, map[string]string{"id": id})
}
func (a *app) attachProof(w http.ResponseWriter, r *http.Request, p map[string]string) {
	var in proofIn
	if !httpx.Decode(w, r, &in) {
		return
	}
	if strings.TrimSpace(in.ObjectKey) == "" {
		httpx.Fail(w, r, 400, "VALIDATION", "object_key is required")
		return
	}
	var status string
	if err := a.db.QueryRowContext(r.Context(), `SELECT status FROM donations WHERE id=?`, p["id"]).Scan(&status); err != nil {
		httpx.Fail(w, r, 404, "NOT_FOUND", "Donation not found")
		return
	}
	if status != "WAITING_PAYMENT" && status != "PENDING" {
		httpx.Fail(w, r, 409, "INVALID_STATE", "Proof cannot be attached in current state")
		return
	}
	id := httpx.NewID()
	if _, err := a.db.ExecContext(r.Context(), `INSERT INTO payment_proofs(id,donation_id,object_key) VALUES(?,?,?)`, id, p["id"], in.ObjectKey); err != nil {
		httpx.Fail(w, r, 500, "SAVE_FAILED", "Could not attach payment proof")
		return
	}
	httpx.JSON(w, 201, map[string]string{"id": id, "status": "PENDING"})
}

func envURL(key, fallback string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return fallback
}
