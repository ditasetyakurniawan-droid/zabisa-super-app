"use client";

import {SyntheticEvent, useMemo, useState} from "react";
import DataTable from "../../../components/DataTable";
import {Card, PageHeader, Pill} from "../../../components/Page";
import {api} from "../../../lib/client";
import {queryErrorMessage, useApiQuery, useRefreshApi} from "../../../lib/query";
import {can, permissions} from "../../../lib/rbac";
import {useSessionUser} from "../../../lib/session";
import type {GuardianCandidate, GuardianLink, Student} from "../../../lib/types";

type CreatedUser = {id: string};

export default function GuardiansPage() {
  const linksQuery = useApiQuery<GuardianLink[]>("/v1/admin/guardian-links");
  const guardianCandidatesQuery = useApiQuery<GuardianCandidate[]>("/v1/admin/guardian-candidates");
  const studentsQuery = useApiQuery<Student[]>("/v1/admin/students");
  const sessionQuery = useSessionUser();
  const refresh = useRefreshApi();
  const [message, setMessage] = useState("");
  const [selectedGuardianId, setSelectedGuardianId] = useState("");

  const links = linksQuery.data ?? [];
  const users = useMemo(() => guardianCandidatesQuery.data ?? [], [guardianCandidatesQuery.data]);
  const students = (studentsQuery.data ?? []).filter(student => student.status === "ACTIVE");
  const canCreateUser = sessionQuery.data
    ? can(sessionQuery.data.role, permissions.usersWrite)
    : false;
  const userById = useMemo(() => new Map(users.map(user => [user.id, user])), [users]);
  const errorMessage =
    message ||
    queryErrorMessage(
      linksQuery.error,
      guardianCandidatesQuery.error,
      studentsQuery.error,
      sessionQuery.error,
    );

  async function createGuardian(event: SyntheticEvent<HTMLFormElement>) {
    event.preventDefault();
    const formEl = event.currentTarget;
    const form = new FormData(formEl);
    const email = String(form.get("email") || "").trim().toLowerCase();
    const existing = users.find(user => user.email.toLowerCase() === email);

    if (existing) {
      if (["GUARDIAN", "WALI_SANTRI"].includes(existing.role)) {
        setSelectedGuardianId(existing.id);
        setMessage(`Email ${email} sudah terdaftar sebagai wali. Akun tersebut sudah dipilih untuk proses linking.`);
      } else {
        setMessage(`Email ${email} sudah terdaftar dengan role ${existing.role}. Kelola role melalui User & Access bila memang harus diubah.`);
      }
      return;
    }

    try {
      const created = await api<CreatedUser>("/v1/admin/users", {
        method: "POST",
        body: JSON.stringify({
          display_name: String(form.get("display_name") || "").trim(),
          email,
          phone: String(form.get("phone") || "").trim(),
          password: String(form.get("password") || ""),
          role: "GUARDIAN",
        }),
      });
      setSelectedGuardianId(created.id);
      formEl.reset();
      setMessage("Akun wali dibuat. Pilih santri dan hubungan, lalu buat request linking. Relationship belum aktif sampai di-approve.");
      await refresh("/v1/admin/guardian-candidates");
    } catch (error) {
      setMessage((error as Error).message);
    }
  }

  async function submit(event: SyntheticEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    try {
      await api("/v1/admin/guardian-links", {
        method: "POST",
        body: JSON.stringify({
          guardian_user_id: String(form.get("guardian_user_id") || ""),
          student_id: String(form.get("student_id") || ""),
          relationship: String(form.get("relationship") || ""),
        }),
      });
      setMessage("Request linking dibuat. Staff berwenang harus melakukan approval sebelum wali dapat membaca data santri.");
      await refresh("/v1/admin/guardian-links");
    } catch (error) {
      setMessage((error as Error).message);
    }
  }

  async function approve(id: string) {
    try {
      await api(`/v1/admin/guardian-links/${id}/approve`, {method: "PATCH"});
      setMessage("Link wali disetujui. Wali sekarang dapat melihat santri tersebut di area privat mobile.");
      await refresh("/v1/admin/guardian-links");
    } catch (error) {
      setMessage((error as Error).message);
    }
  }

  async function reject(id: string) {
    if (!confirm("Tolak request linking ini?")) return;
    try {
      await api(`/v1/admin/guardian-links/${id}/reject`, {method: "PATCH"});
      setMessage("Request linking ditolak.");
      await refresh("/v1/admin/guardian-links");
    } catch (error) {
      setMessage((error as Error).message);
    }
  }

  async function revoke(id: string) {
    if (!confirm("Cabut relationship wali-santri ini? Akses wali ke data santri akan ditutup.")) return;
    try {
      await api(`/v1/admin/guardian-links/${id}/revoke`, {method: "PATCH"});
      setMessage("Relationship wali dicabut. Object-level authorization akan menolak akses wali ke santri tersebut.");
      await refresh("/v1/admin/guardian-links");
    } catch (error) {
      setMessage((error as Error).message);
    }
  }

  return (
    <>
      <PageHeader
        title="Wali & Parent-Student Linking"
        description="Flow aman: buat/pilih akun wali → pilih santri → request relationship → staff approval → akses mobile aktif. Tidak ada auto-link berdasarkan nomor santri atau tanggal lahir."
      />

      {errorMessage && (
        <div className={
          errorMessage.includes("dibuat") ||
          errorMessage.includes("disetujui") ||
          errorMessage.includes("ditolak") ||
          errorMessage.includes("dicabut") ||
          errorMessage.includes("sudah terdaftar sebagai wali")
            ? "alert success"
            : "alert error"
        }>
          {errorMessage}
        </div>
      )}

      <div className="split">
        <Card title="1. Buat akun wali">
          {canCreateUser ? (
            <form className="formGrid" onSubmit={createGuardian}>
              <label>Nama wali<input name="display_name" required /></label>
              <label>Email<input name="email" type="email" required /></label>
              <label>Telepon<input name="phone" inputMode="tel" /></label>
              <label>Password awal<input name="password" type="password" minLength={12} autoComplete="new-password" required /></label>
              <button className="primary" type="submit">Buat akun wali</button>
              <p className="hint">Akun dibuat dengan role GUARDIAN. Role ini dapat login ke mobile, tetapi tidak memperoleh akses Backoffice.</p>
            </form>
          ) : (
            <div className="permissionInfo">
              <strong>Akun wali dibuat oleh ADMIN / SUPER_ADMIN.</strong>
              <p>Role Anda masih dapat melakukan linking bila akun wali sudah tersedia dan memiliki permission guardian management.</p>
            </div>
          )}
        </Card>

        <Card title="2. Hubungkan wali ke santri">
          <form className="formGrid" onSubmit={submit}>
            <label>
              Akun wali
              <select name="guardian_user_id" required value={selectedGuardianId} onChange={event => setSelectedGuardianId(event.target.value)}>
                <option value="">Pilih wali...</option>
                {users.map(user => <option key={user.id} value={user.id}>{user.display_name} · {user.email}</option>)}
              </select>
            </label>
            <label>
              Santri
              <select name="student_id" required defaultValue="" disabled={studentsQuery.isPending}>
                <option value="">{studentsQuery.isPending ? "Memuat santri..." : "Pilih santri..."}</option>
                {students.map(student => <option key={student.id} value={student.id}>{student.student_no} · {student.full_name}</option>)}
              </select>
            </label>
            <label>
              Hubungan
              <select name="relationship" required defaultValue="FATHER">
                <option value="FATHER">Ayah</option>
                <option value="MOTHER">Ibu</option>
                <option value="GUARDIAN">Wali</option>
                <option value="APPROVED_GUARDIAN">Wali yang disetujui</option>
                <option value="OTHER">Lainnya</option>
              </select>
            </label>
            <button className="primary" type="submit">Buat request linking</button>
            <p className="hint">Request selalu dimulai sebagai PENDING. Akses data anak baru aktif setelah approval.</p>
          </form>
        </Card>
      </div>

      <Card title="Aturan akses" className="noteCard">
        <p>Wali hanya dapat membaca santri dengan relationship <strong>APPROVED</strong>. Object-level authorization diperiksa backend untuk tahfidz, nilai, report, dan attendance. Relationship yang dicabut dapat diajukan ulang, tetapi tetap harus di-approve kembali.</p>
      </Card>

      <Card title="Relationship">
        <DataTable
          loading={linksQuery.isPending}
          rows={links}
          columns={[
            {key: "student_name", label: "Santri"},
            {key: "guardian_user_id", label: "Wali", render: row => {
              const user = userById.get(row.guardian_user_id);
              return user ? <span>{user.display_name}<br /><span className="muted">{user.email}</span></span> : <span className="muted">{row.guardian_user_id}</span>;
            }},
            {key: "relationship", label: "Hubungan"},
            {key: "status", label: "Status", render: row => <Pill tone={row.status === "APPROVED" ? "ok" : "warn"}>{row.status}</Pill>},
            {key: "action", label: "Aksi", render: row => row.status === "PENDING" ? (
              <div className="formActions"><button className="small primary" onClick={() => approve(row.id)}>Approve</button><button className="small ghost dark" onClick={() => reject(row.id)}>Tolak</button></div>
            ) : row.status === "APPROVED" ? (
              <button className="small ghost dark" onClick={() => revoke(row.id)}>Cabut</button>
            ) : "-"},
          ]}
        />
      </Card>
    </>
  );
}
