package main

import (
	"database/sql"
	"net/http"
	"strings"
	"time"

	"github.com/zabisa/platform/packages/go/platform/auditx"
	"github.com/zabisa/platform/packages/go/platform/database"
	"github.com/zabisa/platform/packages/go/platform/httpx"
)

type updateCampaignIn struct {
	Name         string   `json:"name"`
	Slug         string   `json:"slug"`
	Description  string   `json:"description"`
	Category     string   `json:"category"`
	TargetAmount *float64 `json:"target_amount"`
	CoverURL     string   `json:"cover_url"`
	Deadline     string   `json:"deadline"`
	Status       string   `json:"status"`
}

type updatePaymentAccountIn struct {
	MethodCode    string `json:"method_code"`
	DisplayName   string `json:"display_name"`
	BankName      string `json:"bank_name"`
	AccountNumber string `json:"account_number"`
	AccountHolder string `json:"account_holder"`
	Instructions  string `json:"instructions"`
	Active        bool   `json:"active"`
}

func (a *app) updateCampaign(w http.ResponseWriter, r *http.Request, p map[string]string) {
	actor, _ := a.access.Claims(r)
	var in updateCampaignIn
	if !httpx.Decode(w, r, &in) {
		return
	}
	in.Name = strings.TrimSpace(in.Name)
	in.Slug = strings.TrimSpace(in.Slug)
	in.Description = strings.TrimSpace(in.Description)
	in.Category = strings.TrimSpace(in.Category)
	in.Status = strings.ToUpper(strings.TrimSpace(in.Status))
	if in.Name == "" || in.Slug == "" || in.Description == "" || in.Category == "" {
		httpx.Fail(w, r, 400, "VALIDATION", "name, slug, description and category are required")
		return
	}
	if in.Status == "" {
		in.Status = "ACTIVE"
	}
	if !map[string]bool{"ACTIVE": true, "PAUSED": true, "COMPLETED": true, "ARCHIVED": true}[in.Status] {
		httpx.Fail(w, r, 400, "VALIDATION", "invalid campaign status")
		return
	}
	var deadline any
	if strings.TrimSpace(in.Deadline) != "" {
		t, err := time.Parse(time.RFC3339, in.Deadline)
		if err != nil {
			httpx.Fail(w, r, 400, "VALIDATION", "deadline must be RFC3339")
			return
		}
		deadline = t.UTC()
	}
	tx, err := a.db.BeginTx(r.Context(), nil)
	if err != nil {
		httpx.Fail(w, r, 500, "TX_FAILED", "Could not update campaign")
		return
	}
	defer tx.Rollback()
	var beforeName, beforeSlug, beforeCategory, beforeStatus string
	var beforeTarget sql.NullFloat64
	if err = tx.QueryRowContext(r.Context(), `SELECT name,slug,category,target_amount,status FROM campaigns WHERE id=? FOR UPDATE`, p["id"]).Scan(&beforeName, &beforeSlug, &beforeCategory, &beforeTarget, &beforeStatus); err == sql.ErrNoRows {
		httpx.Fail(w, r, 404, "NOT_FOUND", "Campaign not found")
		return
	} else if err != nil {
		httpx.Fail(w, r, 500, "QUERY_FAILED", "Could not load campaign")
		return
	}
	if _, err = tx.ExecContext(r.Context(), `UPDATE campaigns SET name=?,slug=?,description=?,category=?,target_amount=?,cover_url=?,deadline=?,status=? WHERE id=?`, in.Name, in.Slug, in.Description, in.Category, in.TargetAmount, database.NullString(in.CoverURL), deadline, in.Status, p["id"]); err != nil {
		httpx.Fail(w, r, 409, "UPDATE_FAILED", "Could not update campaign; slug may already exist")
		return
	}
	before := map[string]any{"name": beforeName, "slug": beforeSlug, "category": beforeCategory, "target_amount": database.NullableFloat(beforeTarget), "status": beforeStatus}
	after := map[string]any{"name": in.Name, "slug": in.Slug, "category": in.Category, "target_amount": in.TargetAmount, "status": in.Status}
	if err = auditx.Add(r.Context(), tx, auditx.FromRequest(r, actor.Sub, "CAMPAIGN_UPDATED", "campaign", p["id"], before, after)); err != nil {
		httpx.Fail(w, r, 500, "AUDIT_ENQUEUE_FAILED", "Could not audit campaign update")
		return
	}
	if err = tx.Commit(); err != nil {
		httpx.Fail(w, r, 500, "COMMIT_FAILED", "Could not update campaign")
		return
	}
	httpx.JSON(w, 200, map[string]any{"id": p["id"], "status": in.Status})
}

func (a *app) listPaymentMethodsAdmin(w http.ResponseWriter, r *http.Request, _ map[string]string) {
	rows, err := a.db.QueryContext(r.Context(), `SELECT id,method_code,display_name,bank_name,account_number,account_holder,instructions,active,created_at,updated_at FROM payment_accounts ORDER BY display_name`)
	if err != nil {
		httpx.Fail(w, r, http.StatusInternalServerError, "QUERY_FAILED", "Could not load payment methods")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id, code, name string
		var bank, number, holder, instructions sql.NullString
		var active bool
		var created, updated time.Time
		if rows.Scan(&id, &code, &name, &bank, &number, &holder, &instructions, &active, &created, &updated) == nil {
			out = append(out, map[string]any{"id": id, "method_code": code, "display_name": name, "bank_name": bank.String, "account_number": number.String, "account_holder": holder.String, "instructions": instructions.String, "active": active, "created_at": created, "updated_at": updated})
		}
	}
	httpx.JSON(w, http.StatusOK, out)
}

func (a *app) updatePaymentMethod(w http.ResponseWriter, r *http.Request, p map[string]string) {
	actor, _ := a.access.Claims(r)
	var in updatePaymentAccountIn
	if !httpx.Decode(w, r, &in) {
		return
	}
	in.MethodCode = strings.TrimSpace(in.MethodCode)
	in.DisplayName = strings.TrimSpace(in.DisplayName)
	if in.MethodCode == "" || in.DisplayName == "" {
		httpx.Fail(w, r, http.StatusBadRequest, "VALIDATION", "method_code and display_name are required")
		return
	}
	tx, err := a.db.BeginTx(r.Context(), nil)
	if err != nil {
		httpx.Fail(w, r, 500, "TX_FAILED", "Could not update payment method")
		return
	}
	defer tx.Rollback()
	var beforeCode, beforeName string
	var beforeActive bool
	if err = tx.QueryRowContext(r.Context(), `SELECT method_code,display_name,active FROM payment_accounts WHERE id=? FOR UPDATE`, p["id"]).Scan(&beforeCode, &beforeName, &beforeActive); err == sql.ErrNoRows {
		httpx.Fail(w, r, http.StatusNotFound, "NOT_FOUND", "Payment method not found")
		return
	} else if err != nil {
		httpx.Fail(w, r, 500, "QUERY_FAILED", "Could not load payment method")
		return
	}
	if _, err = tx.ExecContext(r.Context(), `UPDATE payment_accounts SET method_code=?,display_name=?,bank_name=?,account_number=?,account_holder=?,instructions=?,active=? WHERE id=?`, in.MethodCode, in.DisplayName, database.NullString(in.BankName), database.NullString(in.AccountNumber), database.NullString(in.AccountHolder), database.NullString(in.Instructions), in.Active, p["id"]); err != nil {
		httpx.Fail(w, r, http.StatusConflict, "UPDATE_FAILED", "Could not update payment method; method code may already exist")
		return
	}
	before := map[string]any{"method_code": beforeCode, "display_name": beforeName, "active": beforeActive}
	after := map[string]any{"method_code": in.MethodCode, "display_name": in.DisplayName, "active": in.Active}
	if err = auditx.Add(r.Context(), tx, auditx.FromRequest(r, actor.Sub, "PAYMENT_METHOD_UPDATED", "payment_method", p["id"], before, after)); err != nil {
		httpx.Fail(w, r, 500, "AUDIT_ENQUEUE_FAILED", "Could not audit payment method update")
		return
	}
	if err = tx.Commit(); err != nil {
		httpx.Fail(w, r, 500, "COMMIT_FAILED", "Could not update payment method")
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"id": p["id"], "active": in.Active})
}
