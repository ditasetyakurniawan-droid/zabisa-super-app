"use client";

import {useQueryClient} from "@tanstack/react-query";
import {FormEvent, useState} from "react";
import DataTable from "../../../components/DataTable";
import {Card, PageHeader, Pill} from "../../../components/Page";
import {api} from "../../../lib/client";
import {queryErrorMessage, useApiQuery, useRefreshApi} from "../../../lib/query";
import {roleLabels} from "../../../lib/rbac";
import {sessionQueryKey, useSessionUser} from "../../../lib/session";
import type {AdminUser} from "../../../lib/types";

const operationalRoles = [
  "REGISTERED_PUBLIC",
  "DONOR",
  "GUARDIAN",
  "WALI_SANTRI",
  "USTADZ",
  "GURU_AGAMA",
  "GURU_AKADEMIK",
  "WALI_KELAS",
  "OPERATOR",
  "FINANCE",
  "CONTENT_EDITOR",
] as const;
const allRoles = [...operationalRoles, "ADMIN", "SUPER_ADMIN"] as const;


export default function AccessPage() {
  const usersQuery = useApiQuery<AdminUser[]>("/v1/admin/users");
  const sessionQuery = useSessionUser();
  const queryClient = useQueryClient();
  const refreshApi = useRefreshApi();

  const [selected, setSelected] = useState<AdminUser | null>(null);
  const [message, setMessage] = useState("");

  const rows = usersQuery.data ?? [];
  const me = sessionQuery.data;
  const isSuper = me?.role === "SUPER_ADMIN";
  const errorMessage = message || queryErrorMessage(usersQuery.error, sessionQuery.error);
  const loading = usersQuery.isPending || sessionQuery.isPending;

  async function refresh() {
    await Promise.all([
      refreshApi("/v1/admin/users"),
      queryClient.invalidateQueries({queryKey: sessionQueryKey}),
    ]);
  }

  async function create(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formEl = event.currentTarget;
    const form = new FormData(formEl);

    const email = String(form.get("email") || "").trim().toLowerCase();
    const existing = rows.find(user => user.email.toLowerCase() === email);
    if (existing) {
      setMessage(`Email ${email} sudah terdaftar sebagai ${existing.role}. Gunakan akun yang ada atau ubah role/status melalui aksi Kelola.`);
      return;
    }

    try {
      await api("/v1/admin/users", {
        method: "POST",
        body: JSON.stringify({...Object.fromEntries(form), email}),
      });
      formEl.reset();
      setMessage("Akun dibuat.");
      await refresh();
    } catch (error) {
      setMessage((error as Error).message);
    }
  }

  async function update(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!selected) return;

    const formEl = event.currentTarget;
    const form = new FormData(formEl);

    try {
      await api(`/v1/admin/users/${selected.id}`, {
        method: "PATCH",
        body: JSON.stringify({
          role: form.get("role"),
          status: form.get("status"),
        }),
      });
      setSelected(null);
      setMessage("Hak akses diperbarui dan seluruh sesi user tersebut dicabut.");
      await refresh();
    } catch (error) {
      setMessage((error as Error).message);
    }
  }

  return (
    <>
      <PageHeader
        title="User & Access"
        description="RBAC production baseline. Backend adalah authorization authority; perubahan role/status hanya SUPER_ADMIN dan selalu mencabut sesi aktif target."
      />

      {errorMessage && (
        <div
          role="status"
          aria-live="polite"
          className={
            errorMessage.includes("dibuat") || errorMessage.includes("diperbarui")
              ? "alert success"
              : "alert error"
          }
        >
          {errorMessage}
        </div>
      )}

      <div className="split">
        <Card title="Buat akun">
          <form className="formGrid" onSubmit={create}>
            <label>
              Nama
              <input name="display_name" required />
            </label>
            <label>
              Email
              <input name="email" type="email" required />
            </label>
            <label>
              Telepon
              <input name="phone" />
            </label>
            <label>
              Password awal
              <input name="password" type="password" minLength={12} required />
            </label>
            <label>
              Role
              <select name="role" required defaultValue="">
                <option value="">Pilih...</option>
                {(isSuper ? allRoles : operationalRoles).map(role => (
                  <option key={role} value={role}>
                    {roleLabels[role as keyof typeof roleLabels] || role}
                  </option>
                ))}
              </select>
            </label>
            <button className="primary" type="submit">
              Buat akun
            </button>
          </form>
          {!isSuper && (
            <p className="hint">Administrator biasa tidak dapat membuat ADMIN / SUPER_ADMIN.</p>
          )}
        </Card>

        <Card title={selected ? "Ubah hak akses" : "Hak akses"}>
          {isSuper && selected ? (
            <form key={selected.id} className="formGrid" onSubmit={update}>
              <div className="selectedUser">
                <strong>{selected.display_name}</strong>
                <span>{selected.email}</span>
              </div>

              <label>
                Role
                <select name="role" defaultValue={selected.role} required>
                  {allRoles.map(role => (
                    <option key={role} value={role}>
                      {roleLabels[role as keyof typeof roleLabels] || role}
                    </option>
                  ))}
                </select>
              </label>

              <label>
                Status
                <select name="status" defaultValue={selected.status} required>
                  <option value="ACTIVE">ACTIVE</option>
                  <option value="INACTIVE">INACTIVE</option>
                </select>
              </label>

              <div className="alert warnBox">
                Perubahan role/status akan revoke seluruh session user target. Last active
                SUPER_ADMIN tidak dapat dinonaktifkan atau didemote.
              </div>

              <div className="formActions">
                <button className="primary" type="submit">
                  Simpan akses
                </button>
                <button
                  className="ghost dark"
                  type="button"
                  onClick={() => setSelected(null)}
                >
                  Batal
                </button>
              </div>
            </form>
          ) : (
            <div className="permissionInfo">
              <strong>
                {isSuper
                  ? "Pilih user dari tabel untuk mengubah role/status."
                  : "Role/status hanya dapat diubah SUPER_ADMIN."}
              </strong>
              <p>
                ABAC berbasis kelas/unit/kelompok akan ditambahkan pada fase assignment scope
                berikutnya. RBAC ini tidak menggantikan pembatasan ownership wali di backend.
              </p>
            </div>
          )}
        </Card>
      </div>

      <Card title="Daftar user">
        <DataTable
          loading={loading}
          rows={rows}
          columns={[
            {key: "display_name", label: "Nama"},
            {key: "email", label: "Email"},
            {
              key: "role",
              label: "Role",
              render: row => (
                <Pill tone="info">
                  {roleLabels[row.role as keyof typeof roleLabels] || row.role}
                </Pill>
              ),
            },
            {
              key: "status",
              label: "Status",
              render: row => (
                <Pill tone={row.status === "ACTIVE" ? "ok" : "warn"}>{row.status}</Pill>
              ),
            },
            {
              key: "__action",
              label: "Aksi",
              render: row =>
                isSuper ? (
                  <button className="ghost small dark" onClick={() => setSelected(row)}>
                    Kelola
                  </button>
                ) : (
                  <span className="muted">Read only</span>
                ),
            },
          ]}
        />
      </Card>
    </>
  );
}
