package main

import (
	"context"
	"database/sql"
	"net/http"
	"strings"
	"time"

	"github.com/zabisa/platform/packages/go/platform/auditx"
	"github.com/zabisa/platform/packages/go/platform/database"
	"github.com/zabisa/platform/packages/go/platform/httpx"
)

const createCampaignUpdateFailure = "Could not create campaign update"

type campaignUpdateIn struct {
	Title string `json:"title"`
	Body  string `json:"body"`
}

func (a *app) listCampaignsAdmin(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	rows, err := a.db.QueryContext(r.Context(), `SELECT id,name,slug,description,category,target_amount,collected_amount,cover_url,deadline,status,created_at FROM campaigns ORDER BY created_at DESC LIMIT 300`)
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
		var created time.Time
		if rows.Scan(&id, &name, &slug, &desc, &cat, &target, &collected, &cover, &deadline, &status, &created) == nil {
			out = append(out, map[string]any{"id": id, "name": name, "slug": slug, "description": desc, "category": cat, "target_amount": database.NullableFloat(target), "collected_amount": collected, "cover_url": cover.String, "deadline": database.NullableTime(deadline), "status": status, "created_at": created})
		}
	}
	httpx.JSON(w, 200, out)
}

func (a *app) listDonationsAdmin(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	status := strings.TrimSpace(r.URL.Query().Get("status"))
	rows, err := a.db.QueryContext(r.Context(), `SELECT d.id,d.campaign_id,c.name,d.donor_name,d.donor_email,d.anonymous,d.message,d.amount,d.status,d.payment_method,d.created_at,d.updated_at,(SELECT COUNT(*) FROM payment_proofs p WHERE p.donation_id=d.id) proof_count FROM donations d JOIN campaigns c ON c.id=d.campaign_id WHERE (?='' OR d.status=?) ORDER BY d.created_at DESC LIMIT 500`, status, status)
	if err != nil {
		httpx.Fail(w, r, 500, "QUERY_FAILED", "Could not load donations")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id, cid, cname, status, method string
		var donorName, donorEmail, message sql.NullString
		var anon bool
		var amount float64
		var created, updated time.Time
		var proofCount int
		if rows.Scan(&id, &cid, &cname, &donorName, &donorEmail, &anon, &message, &amount, &status, &method, &created, &updated, &proofCount) == nil {
			out = append(out, map[string]any{"id": id, "campaign_id": cid, "campaign_name": cname, "donor_name": donorName.String, "donor_email": donorEmail.String, "anonymous": anon, "message": message.String, "amount": amount, "status": status, "payment_method": method, "proof_count": proofCount, "created_at": created, "updated_at": updated})
		}
	}
	httpx.JSON(w, 200, out)
}

func (a *app) listDonationHistory(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	c, err := a.access.Claims(r)
	if err != nil {
		httpx.Fail(w, r, 401, "UNAUTHORIZED", "Authentication required")
		return
	}
	rows, err := a.db.QueryContext(r.Context(), `SELECT d.id,d.campaign_id,c.name,d.amount,d.status,d.payment_method,d.created_at FROM donations d JOIN campaigns c ON c.id=d.campaign_id WHERE d.donor_user_id=? ORDER BY d.created_at DESC LIMIT 200`, c.Sub)
	if err != nil {
		httpx.Fail(w, r, 500, "QUERY_FAILED", "Could not load donation history")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id, cid, name, status, method string
		var amount float64
		var created time.Time
		if rows.Scan(&id, &cid, &name, &amount, &status, &method, &created) == nil {
			out = append(out, map[string]any{"id": id, "campaign_id": cid, "campaign_name": name, "amount": amount, "status": status, "payment_method": method, "created_at": created})
		}
	}
	httpx.JSON(w, 200, out)
}

func (a *app) createCampaignUpdate(w http.ResponseWriter, r *http.Request, p map[string]string) {
	actor, _ := a.access.Claims(r)
	var in campaignUpdateIn
	if !httpx.Decode(w, r, &in) {
		return
	}
	in.Title = strings.TrimSpace(in.Title)
	in.Body = strings.TrimSpace(in.Body)
	if in.Title == "" || in.Body == "" {
		httpx.Fail(w, r, 400, "VALIDATION", "title and body are required")
		return
	}
	id := httpx.NewID()
	tx, err := a.db.BeginTx(r.Context(), nil)
	if err != nil {
		httpx.Fail(w, r, 500, "TX_FAILED", createCampaignUpdateFailure)
		return
	}
	defer tx.Rollback()
	var campaignExists int
	if err = tx.QueryRowContext(r.Context(), `SELECT COUNT(*) FROM campaigns WHERE id=?`, p["id"]).Scan(&campaignExists); err != nil || campaignExists == 0 {
		httpx.Fail(w, r, 404, "NOT_FOUND", "Campaign not found")
		return
	}
	if _, err = tx.ExecContext(r.Context(), `INSERT INTO campaign_updates(id,campaign_id,title,body) VALUES(?,?,?,?)`, id, p["id"], in.Title, in.Body); err != nil {
		httpx.Fail(w, r, 500, "SAVE_FAILED", createCampaignUpdateFailure)
		return
	}
	after := map[string]any{"campaign_id": p["id"], "title": in.Title}
	if err = auditx.Add(r.Context(), tx, auditx.FromRequest(r, actor.Sub, "CAMPAIGN_UPDATE_CREATED", "campaign_update", id, nil, after)); err != nil {
		httpx.Fail(w, r, 500, "AUDIT_ENQUEUE_FAILED", "Could not audit campaign update")
		return
	}
	if err = tx.Commit(); err != nil {
		httpx.Fail(w, r, 500, "COMMIT_FAILED", createCampaignUpdateFailure)
		return
	}
	httpx.JSON(w, 201, map[string]string{"id": id})
}
func (a *app) listCampaignUpdates(w http.ResponseWriter, r *http.Request, p map[string]string) {
	rows, err := a.db.QueryContext(r.Context(), `SELECT id,title,body,created_at FROM campaign_updates WHERE campaign_id=? ORDER BY created_at DESC LIMIT 100`, p["id"])
	if err != nil {
		httpx.Fail(w, r, 500, "QUERY_FAILED", "Could not load campaign updates")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id, title, body string
		var created time.Time
		if rows.Scan(&id, &title, &body, &created) == nil {
			out = append(out, map[string]any{"id": id, "title": title, "body": body, "created_at": created})
		}
	}
	httpx.JSON(w, 200, out)
}

func (a *app) seedLocal(ctx context.Context) error {
	_, err := a.db.ExecContext(ctx, `INSERT INTO payment_accounts(id,method_code,display_name,bank_name,account_number,account_holder,instructions,active) VALUES(?,?,?,?,?,?,?,TRUE) ON DUPLICATE KEY UPDATE display_name=VALUES(display_name),instructions=VALUES(instructions),active=TRUE`, "00000000-0000-4000-8000-000000000301", "MANUAL_TRANSFER", "Transfer Manual (Development)", nil, nil, nil, "DEVELOPMENT DATA: configure a real payment account from Backoffice before production.")
	return err
}
