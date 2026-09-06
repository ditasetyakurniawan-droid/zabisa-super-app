"use client";

import {SyntheticEvent, useState} from "react";
import DataTable from "../../../components/DataTable";
import {Card, PageHeader, Pill} from "../../../components/Page";
import {api, dateTime, money} from "../../../lib/client";
import {queryErrorMessage, useApiQuery, useRefreshApi} from "../../../lib/query";
import type {DonationCampaign, DonationTransaction, PaymentMethod} from "../../../lib/types";

function localDateTime(value?: string | null) {
  if (!value) return "";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "";
  const local = new Date(date.getTime() - date.getTimezoneOffset() * 60_000);
  return local.toISOString().slice(0, 16);
}

function donationStatusTone(status: string) {
  if (status === "PAID") return "ok" as const;
  if (status === "FAILED") return "danger" as const;
  return "warn" as const;
}

export default function DonationPage() {
  const campaignsQuery = useApiQuery<DonationCampaign[]>("/v1/admin/donation/campaigns");
  const donationsQuery = useApiQuery<DonationTransaction[]>("/v1/admin/donations");
  const methodsQuery = useApiQuery<PaymentMethod[]>("/v1/admin/donation/payment-methods");
  const refresh = useRefreshApi();
  const [message, setMessage] = useState("");
  const [editingCampaign, setEditingCampaign] = useState<DonationCampaign | null>(null);
  const [editingMethod, setEditingMethod] = useState<PaymentMethod | null>(null);

  const campaigns = campaignsQuery.data ?? [];
  const donations = donationsQuery.data ?? [];
  const methods = methodsQuery.data ?? [];
  const errorMessage = message || queryErrorMessage(campaignsQuery.error, donationsQuery.error, methodsQuery.error);

  async function saveCampaign(event: SyntheticEvent<HTMLFormElement>) {
    event.preventDefault();
    const formEl = event.currentTarget;
    const form = new FormData(formEl);
    const rawDeadline = String(form.get("deadline") || "");
    const payload = {
      name: form.get("name"),
      slug: form.get("slug"),
      description: form.get("description"),
      category: form.get("category"),
      target_amount: Number(form.get("target_amount")) || null,
      cover_url: form.get("cover_url"),
      deadline: rawDeadline ? new Date(rawDeadline).toISOString() : "",
      status: form.get("status") || "ACTIVE",
    };
    try {
      await api(editingCampaign ? `/v1/admin/donation/campaigns/${editingCampaign.id}` : "/v1/admin/donation/campaigns", {
        method: editingCampaign ? "PATCH" : "POST",
        body: JSON.stringify(
          editingCampaign
            ? payload
            : {
                name: payload.name,
                slug: payload.slug,
                description: payload.description,
                category: payload.category,
                target_amount: payload.target_amount,
                cover_url: payload.cover_url,
                deadline: payload.deadline || null,
              },
        ),
      });
      formEl.reset();
      setEditingCampaign(null);
      setMessage(editingCampaign ? "Campaign diperbarui." : "Campaign tersimpan.");
      await refresh("/v1/admin/donation/campaigns");
    } catch (error) {
      setMessage((error as Error).message);
    }
  }

  async function savePaymentMethod(event: SyntheticEvent<HTMLFormElement>) {
    event.preventDefault();
    const formEl = event.currentTarget;
    const form = new FormData(formEl);
    const basePayload = {
      method_code: form.get("method_code"),
      display_name: form.get("display_name"),
      bank_name: form.get("bank_name"),
      account_number: form.get("account_number"),
      account_holder: form.get("account_holder"),
      instructions: form.get("instructions"),
    };
    const updatePayload = {...basePayload, active: form.get("active") === "on"};
    try {
      await api(editingMethod ? `/v1/admin/donation/payment-methods/${editingMethod.id}` : "/v1/admin/donation/payment-methods", {
        method: editingMethod ? "PATCH" : "POST",
        body: JSON.stringify(editingMethod ? updatePayload : basePayload),
      });
      formEl.reset();
      setEditingMethod(null);
      setMessage(editingMethod ? "Metode pembayaran diperbarui." : "Metode pembayaran tersimpan.");
      await refresh("/v1/admin/donation/payment-methods");
    } catch (error) {
      setMessage((error as Error).message);
    }
  }

  async function createCampaignUpdate(event: SyntheticEvent<HTMLFormElement>) {
    event.preventDefault();
    const formEl = event.currentTarget;
    const form = new FormData(formEl);
    const id = String(form.get("campaign_id"));
    try {
      await api(`/v1/admin/donation/campaigns/${id}/updates`, {
        method: "POST",
        body: JSON.stringify({title: form.get("title"), body: form.get("body")}),
      });
      formEl.reset();
      setMessage("Update campaign tersimpan.");
    } catch (error) {
      setMessage((error as Error).message);
    }
  }

  async function verifyDonation(id: string) {
    if (!confirm("Verifikasi pembayaran ini sebagai PAID? Backend akan menjadi source of truth status transaksi.")) return;
    try {
      await api(`/v1/admin/donations/${id}/verify`, {method: "PATCH"});
      setMessage("Pembayaran terverifikasi.");
      await refresh("/v1/admin/donations", "/v1/admin/donation/campaigns");
    } catch (error) {
      setMessage((error as Error).message);
    }
  }

  return (
    <>
      <PageHeader
        title="Donation Management"
        description="Campaign lifecycle, rekening configurable, transaksi, verifikasi manual, campaign update, dan rekonsiliasi backend sebagai source of truth."
      />

      {errorMessage && (
        <div role="status" aria-live="polite" className={/tersimpan|diperbarui|terverifikasi/.test(errorMessage) ? "alert success" : "alert error"}>{errorMessage}</div>
      )}

      <div className="statsGrid">
        <div className="stat"><span>Total campaign</span><strong>{campaigns.length}</strong></div>
        <div className="stat"><span>Dana terverifikasi</span><strong>{money(campaigns.reduce((total, campaign) => total + Number(campaign.collected_amount || 0), 0))}</strong></div>
        <div className="stat"><span>Menunggu pembayaran</span><strong>{donations.filter(donation => ["WAITING_PAYMENT", "PENDING"].includes(donation.status)).length}</strong></div>
        <div className="stat"><span>Metode aktif</span><strong>{methods.filter(method => method.active).length}</strong></div>
      </div>

      <div className="split">
        <Card title={editingCampaign ? "Edit campaign" : "Buat campaign"}>
          <form key={editingCampaign?.id || "new-campaign"} className="formGrid" onSubmit={saveCampaign}>
            <label>Nama<input name="name" required defaultValue={editingCampaign?.name || ""} /></label>
            <label>Slug<input name="slug" required defaultValue={editingCampaign?.slug || ""} /></label>
            <label>Deskripsi<textarea name="description" required defaultValue={editingCampaign?.description || ""} /></label>
            <label>Kategori<input name="category" required defaultValue={editingCampaign?.category || ""} /></label>
            <label>Target<input name="target_amount" type="number" min="0" defaultValue={editingCampaign?.target_amount == null ? "" : String(editingCampaign.target_amount)} /></label>
            <label>Cover URL<input name="cover_url" defaultValue={editingCampaign?.cover_url || ""} /></label>
            <label>Deadline<input name="deadline" type="datetime-local" defaultValue={localDateTime(editingCampaign?.deadline)} /></label>
            {editingCampaign && (
              <label>Status<select name="status" defaultValue={editingCampaign.status}><option value="ACTIVE">ACTIVE</option><option value="PAUSED">PAUSED</option><option value="COMPLETED">COMPLETED</option><option value="ARCHIVED">ARCHIVED</option></select></label>
            )}
            <div className="formActions">
              <button className="primary">{editingCampaign ? "Perbarui campaign" : "Simpan campaign"}</button>
              {editingCampaign && <button className="ghost dark" type="button" onClick={() => setEditingCampaign(null)}>Batal</button>}
            </div>
          </form>
        </Card>

        <Card title={editingMethod ? "Edit metode pembayaran" : "Rekening / metode pembayaran"}>
          <form key={editingMethod?.id || "new-method"} className="formGrid" onSubmit={savePaymentMethod}>
            <label>Kode metode<input name="method_code" placeholder="BANK_BSI" required defaultValue={editingMethod?.method_code || ""} /></label>
            <label>Nama tampilan<input name="display_name" placeholder="Transfer Bank BSI" required defaultValue={editingMethod?.display_name || ""} /></label>
            <label>Bank<input name="bank_name" defaultValue={editingMethod?.bank_name || ""} /></label>
            <label>Nomor rekening<input name="account_number" defaultValue={editingMethod?.account_number || ""} /></label>
            <label>Atas nama<input name="account_holder" defaultValue={editingMethod?.account_holder || ""} /></label>
            <label>Instruksi<textarea name="instructions" defaultValue={editingMethod?.instructions || ""} /></label>
            {editingMethod && <label className="check"><input name="active" type="checkbox" defaultChecked={editingMethod.active} /> Aktif</label>}
            <div className="formActions">
              <button className="primary">{editingMethod ? "Perbarui metode" : "Simpan metode"}</button>
              {editingMethod && <button className="ghost dark" type="button" onClick={() => setEditingMethod(null)}>Batal</button>}
            </div>
          </form>
        </Card>
      </div>

      <div className="split">
        <Card title="Update campaign">
          <form className="formGrid" onSubmit={createCampaignUpdate}>
            <label>Campaign<select name="campaign_id" required defaultValue=""><option value="">Pilih...</option>{campaigns.filter(campaign => campaign.status !== "ARCHIVED").map(campaign => <option key={campaign.id} value={campaign.id}>{campaign.name}</option>)}</select></label>
            <label>Judul update<input name="title" required /></label>
            <label>Isi update<textarea name="body" required /></label>
            <button className="primary">Publikasikan update</button>
          </form>
        </Card>
        <Card title="Metode pembayaran">
          <DataTable rows={methods} loading={methodsQuery.isPending} columns={[
            {key: "display_name", label: "Metode"},
            {key: "method_code", label: "Kode"},
            {key: "bank_name", label: "Bank"},
            {key: "active", label: "Status", render: row => <Pill tone={row.active ? "ok" : "warn"}>{row.active ? "ACTIVE" : "INACTIVE"}</Pill>},
            {key: "action", label: "Aksi", render: row => <button className="ghost small dark" onClick={() => setEditingMethod(row)}>Edit</button>},
          ]} />
        </Card>
      </div>

      <Card title="Transaksi donasi">
        <DataTable loading={donationsQuery.isPending} rows={donations} columns={[
          {key: "created_at", label: "Waktu", render: row => dateTime(row.created_at)},
          {key: "campaign_name", label: "Campaign"},
          {key: "donor_name", label: "Donor", render: row => row.anonymous ? "Anonim" : row.donor_name || "-"},
          {key: "amount", label: "Nominal", render: row => money(row.amount)},
          {key: "payment_method", label: "Metode"},
          {key: "status", label: "Status", render: row => <Pill tone={donationStatusTone(row.status)}>{row.status}</Pill>},
          {key: "action", label: "Aksi", render: row => ["WAITING_PAYMENT", "PENDING"].includes(row.status) ? <button className="small primary" onClick={() => verifyDonation(row.id)}>Verifikasi</button> : "-"},
        ]} />
      </Card>

      <Card title="Campaign">
        <DataTable loading={campaignsQuery.isPending} rows={campaigns} columns={[
          {key: "name", label: "Campaign"},
          {key: "category", label: "Kategori"},
          {key: "collected_amount", label: "Terkumpul", render: row => money(row.collected_amount)},
          {key: "target_amount", label: "Target", render: row => row.target_amount ? money(row.target_amount) : "-"},
          {key: "status", label: "Status", render: row => <Pill tone={row.status === "ACTIVE" ? "ok" : "warn"}>{row.status}</Pill>},
          {key: "action", label: "Aksi", render: row => <button className="ghost small dark" onClick={() => setEditingCampaign(row)}>Edit</button>},
        ]} />
      </Card>
    </>
  );
}
