package main

import (
	"context"
	"database/sql"
	"embed"
	"net/http"
	"strings"
	"time"

	"github.com/zabisa/platform/packages/go/platform/access"
	"github.com/zabisa/platform/packages/go/platform/auditx"
	"github.com/zabisa/platform/packages/go/platform/authz"
	"github.com/zabisa/platform/packages/go/platform/config"
	"github.com/zabisa/platform/packages/go/platform/database"
	"github.com/zabisa/platform/packages/go/platform/httpx"
	"github.com/zabisa/platform/packages/go/platform/outbox"
	"github.com/zabisa/platform/packages/go/platform/service"
)

//go:embed migrations/*.sql
var migrationFS embed.FS

const (
	createCampaignFailure      = "Could not create campaign"
	donationNotFound           = "Donation not found"
	createPaymentMethodFailure = "Could not create payment method"
)

type app struct {
	db     *sql.DB
	cfg    config.Config
	access access.Control
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
	service.MustRun(service.Options{Name: "donation-service", Database: "donation_db", Port: 8086, Migrations: migrationFS, Build: buildService})
}

func buildService(ctx context.Context, db *sql.DB, cfg config.Config) (http.Handler, error) {
	a := &app{db: db, cfg: cfg, access: access.Control{JWTKey: cfg.JWTKey, InternalKey: cfg.InternalServiceKey}}
	go outbox.Worker{DB: db, AuditEndpoint: config.Env("AUDIT_SERVICE_URL", "http://identity:8081/internal/v1/audit-events"), InternalKey: cfg.InternalServiceKey, Service: cfg.Service}.Run(ctx)
	if cfg.Environment == "local" {
		if err := a.seedLocal(ctx); err != nil {
			return nil, err
		}
	}
	routes := service.Router(db)
	routes.Handle("GET", "/api/v1/donation/campaigns", a.listCampaigns)
	routes.Handle("GET", "/api/v1/donation/payment-methods", a.listPaymentMethods)
	routes.Handle("POST", "/api/v1/admin/donation/payment-methods", a.access.RequirePermission(authz.DonationWrite, a.createPaymentMethod))
	routes.Handle("GET", "/api/v1/admin/donation/payment-methods", a.access.RequirePermission(authz.DonationRead, a.listPaymentMethodsAdmin))
	routes.Handle("PATCH", "/api/v1/admin/donation/payment-methods/{id}", a.access.RequirePermission(authz.DonationWrite, a.updatePaymentMethod))
	routes.Handle("POST", "/api/v1/admin/donation/campaigns", a.access.RequirePermission(authz.DonationWrite, a.createCampaign))
	routes.Handle("GET", "/api/v1/admin/donation/campaigns", a.access.RequirePermission(authz.DonationRead, a.listCampaignsAdmin))
	routes.Handle("PATCH", "/api/v1/admin/donation/campaigns/{id}", a.access.RequirePermission(authz.DonationWrite, a.updateCampaign))
	routes.Handle("GET", "/api/v1/admin/donations", a.access.RequirePermission(authz.DonationRead, a.listDonationsAdmin))
	routes.Handle("POST", "/api/v1/donations", a.createDonation)
	routes.Handle("GET", "/api/v1/donations/history", a.listDonationHistory)
	routes.Handle("GET", "/api/v1/donations/{id}", a.getDonation)
	routes.Handle("GET", "/api/v1/donation/campaigns/{id}/updates", a.listCampaignUpdates)
	routes.Handle("POST", "/api/v1/admin/donation/campaigns/{id}/updates", a.access.RequirePermission(authz.DonationWrite, a.createCampaignUpdate))
	routes.Handle("POST", "/api/v1/donations/{id}/proof", a.attachProof)
	routes.Handle("PATCH", "/api/v1/admin/donations/{id}/verify", a.access.RequirePermission(authz.DonationVerify, a.verifyDonation))
	return routes, nil
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
			out = append(out, map[string]any{"id": id, "name": name, "slug": slug, "description": desc, "category": cat, "target_amount": database.NullableFloat(target), "collected_amount": collected, "cover_url": cover.String, "deadline": database.NullableTime(deadline), "status": status})
		}
	}
	httpx.JSON(w, 200, out)
}
func (a *app) createCampaign(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	actor, _ := a.access.Claims(r)
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
		httpx.Fail(w, r, 500, "TX_FAILED", createCampaignFailure)
		return
	}
	defer tx.Rollback()
	if _, err = tx.ExecContext(r.Context(), `INSERT INTO campaigns(id,name,slug,description,category,target_amount,cover_url,deadline) VALUES(?,?,?,?,?,?,?,?)`, id, in.Name, in.Slug, in.Description, in.Category, in.TargetAmount, database.NullString(in.CoverURL), in.Deadline); err != nil {
		httpx.Fail(w, r, 409, "CREATE_FAILED", createCampaignFailure)
		return
	}
	after := map[string]any{"name": in.Name, "slug": in.Slug, "category": in.Category, "target_amount": in.TargetAmount, "status": "ACTIVE"}
	if err = auditx.Add(r.Context(), tx, auditx.FromRequest(r, actor.Sub, "CAMPAIGN_CREATED", "campaign", id, nil, after)); err != nil {
		httpx.Fail(w, r, 500, "AUDIT_ENQUEUE_FAILED", "Could not audit campaign")
		return
	}
	if err = tx.Commit(); err != nil {
		httpx.Fail(w, r, 500, "COMMIT_FAILED", createCampaignFailure)
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
		if c, verifyErr := a.access.Claims(r); verifyErr == nil {
			donorUserID = c.Sub
		}
	}
	_, err = a.db.ExecContext(r.Context(), `INSERT INTO donations(id,campaign_id,donor_user_id,donor_name,donor_email,anonymous,message,amount,payment_method,idempotency_key) VALUES(?,?,?,?,?,?,?,?,?,?)`, id, in.CampaignID, donorUserID, database.NullString(in.DonorName), database.NullString(in.DonorEmail), in.Anonymous, database.NullString(in.Message), in.Amount, in.PaymentMethod, key)
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
		httpx.Fail(w, r, 404, "NOT_FOUND", donationNotFound)
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
		httpx.Fail(w, r, 404, "NOT_FOUND", donationNotFound)
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
	actor, _ := a.access.Claims(r)
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
	actor, _ := a.access.Claims(r)
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
		httpx.Fail(w, r, 500, "TX_FAILED", createPaymentMethodFailure)
		return
	}
	defer tx.Rollback()
	if _, err = tx.ExecContext(r.Context(), `INSERT INTO payment_accounts(id,method_code,display_name,bank_name,account_number,account_holder,instructions) VALUES(?,?,?,?,?,?,?)`, id, in.MethodCode, in.DisplayName, database.NullString(in.BankName), database.NullString(in.AccountNumber), database.NullString(in.AccountHolder), database.NullString(in.Instructions)); err != nil {
		httpx.Fail(w, r, 409, "CREATE_FAILED", createPaymentMethodFailure)
		return
	}
	after := map[string]any{"method_code": in.MethodCode, "display_name": in.DisplayName, "active": true}
	if err = auditx.Add(r.Context(), tx, auditx.FromRequest(r, actor.Sub, "PAYMENT_METHOD_CREATED", "payment_method", id, nil, after)); err != nil {
		httpx.Fail(w, r, 500, "AUDIT_ENQUEUE_FAILED", "Could not audit payment method creation")
		return
	}
	if err = tx.Commit(); err != nil {
		httpx.Fail(w, r, 500, "COMMIT_FAILED", createPaymentMethodFailure)
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
		httpx.Fail(w, r, 404, "NOT_FOUND", donationNotFound)
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
