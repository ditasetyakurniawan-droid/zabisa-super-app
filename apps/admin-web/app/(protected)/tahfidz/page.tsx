"use client";

import {FormEvent, useState} from "react";
import DataTable from "../../../components/DataTable";
import {Card, PageHeader, Pill} from "../../../components/Page";
import {api} from "../../../lib/client";
import {queryErrorMessage, useApiQuery, useRefreshApi} from "../../../lib/query";
import type {Student, TahfidzEntry, TahfidzTarget} from "../../../lib/types";

export default function TahfidzPage() {
  const studentsQuery = useApiQuery<Student[]>("/v1/admin/students");
  const entriesQuery = useApiQuery<TahfidzEntry[]>("/v1/tahfidz/entries");
  const targetsQuery = useApiQuery<TahfidzTarget[]>("/v1/tahfidz/targets");
  const refresh = useRefreshApi();
  const [message, setMessage] = useState("");
  const [editingTarget, setEditingTarget] = useState<TahfidzTarget | null>(null);

  const students = studentsQuery.data ?? [];
  const entries = entriesQuery.data ?? [];
  const targets = targetsQuery.data ?? [];
  const errorMessage =
    message ||
    queryErrorMessage(studentsQuery.error, entriesQuery.error, targetsQuery.error);

  async function createEntry(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formEl = event.currentTarget;
    const form = new FormData(formEl);
    const payload = {
      student_id: form.get("student_id"),
      activity_date: form.get("activity_date"),
      surah: form.get("surah"),
      ayah_start: Number(form.get("ayah_start")),
      ayah_end: Number(form.get("ayah_end")),
      juz: form.get("juz") ? Number(form.get("juz")) : null,
      page: form.get("page") ? Number(form.get("page")) : null,
      activity_type: form.get("activity_type"),
      score: form.get("score") ? Number(form.get("score")) : null,
      fluency: form.get("fluency"),
      tajwid: form.get("tajwid"),
      makhraj: form.get("makhraj"),
      teacher_note: form.get("teacher_note"),
    };

    try {
      await api("/v1/tahfidz/entries", {
        method: "POST",
        body: JSON.stringify(payload),
      });
      formEl.reset();
      setMessage("Setoran tersimpan dan event notifikasi dibuat.");
      await refresh("/v1/tahfidz/entries");
    } catch (error) {
      setMessage((error as Error).message);
    }
  }

  async function saveTarget(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formEl = event.currentTarget;
    const form = new FormData(formEl);
    const createPayload = {
      student_id: form.get("student_id"),
      target_juz: Number(form.get("target_juz")),
      target_date: form.get("target_date"),
    };
    const updatePayload = {
      target_juz: Number(form.get("target_juz")),
      target_date: form.get("target_date"),
    };

    try {
      await api(
        editingTarget ? `/v1/tahfidz/targets/${editingTarget.id}` : "/v1/tahfidz/targets",
        {
          method: editingTarget ? "PATCH" : "POST",
          body: JSON.stringify(editingTarget ? updatePayload : createPayload),
        },
      );
      formEl.reset();
      setEditingTarget(null);
      setMessage(editingTarget ? "Target diperbarui." : "Target tersimpan.");
      await refresh("/v1/tahfidz/targets");
    } catch (error) {
      setMessage((error as Error).message);
    }
  }

  return (
    <>
      <PageHeader
        title="Tahfidz"
        description="Setoran, murajaah, tasmi, evaluasi kualitas, target, transactional outbox, dan notifikasi wali."
      />

      {errorMessage && (
        <div
          role="status"
          aria-live="polite"
          className={
            errorMessage.includes("tersimpan") || errorMessage.includes("dibuat")
              ? "alert success"
              : "alert error"
          }
        >
          {errorMessage}
        </div>
      )}

      <div className="split">
        <Card title="Input setoran">
          <form className="formGrid" onSubmit={createEntry}>
            <label>
              Santri
              <select name="student_id" required defaultValue="" disabled={studentsQuery.isPending}>
                <option value="">{studentsQuery.isPending ? "Memuat santri..." : "Pilih..."}</option>
                {students.map(student => (
                  <option key={student.id} value={student.id}>
                    {student.student_no} · {student.full_name}
                  </option>
                ))}
              </select>
            </label>

            <label>
              Tanggal
              <input name="activity_date" type="date" required />
            </label>
            <label>
              Surah
              <input name="surah" required />
            </label>

            <div className="two">
              <label>
                Ayat awal
                <input name="ayah_start" type="number" min="1" required />
              </label>
              <label>
                Ayat akhir
                <input name="ayah_end" type="number" min="1" required />
              </label>
            </div>

            <div className="two">
              <label>
                Juz
                <input name="juz" type="number" min="1" max="30" />
              </label>
              <label>
                Halaman
                <input name="page" type="number" min="1" />
              </label>
            </div>

            <label>
              Aktivitas
              <select name="activity_type" defaultValue="NEW_MEMORIZATION">
                <option value="NEW_MEMORIZATION">Hafalan baru</option>
                <option value="MURAJAAH">Murajaah</option>
                <option value="TASMI">Tasmi</option>
              </select>
            </label>

            <label>
              Nilai
              <input name="score" type="number" step="0.01" min="0" max="100" />
            </label>

            <div className="two">
              <label>
                Kelancaran
                <input name="fluency" />
              </label>
              <label>
                Tajwid
                <input name="tajwid" />
              </label>
            </div>

            <label>
              Makhraj
              <input name="makhraj" />
            </label>
            <label>
              Catatan
              <textarea name="teacher_note" />
            </label>

            <button className="primary">Simpan setoran</button>
          </form>
        </Card>

        <Card title={editingTarget ? "Edit target tahfidz" : "Target tahfidz"}>
          <form key={editingTarget?.id || "new-target"} className="formGrid" onSubmit={saveTarget}>
            <label>
              Santri
              <select
                name="student_id"
                required
                defaultValue={editingTarget?.student_id || ""}
                disabled={Boolean(editingTarget) || studentsQuery.isPending}
              >
                <option value="">{studentsQuery.isPending ? "Memuat santri..." : "Pilih..."}</option>
                {students.map(student => (
                  <option key={student.id} value={student.id}>
                    {student.full_name}
                  </option>
                ))}
              </select>
            </label>

            <label>
              Target juz
              <input name="target_juz" type="number" step="0.1" min="0.1" max="30" required defaultValue={editingTarget ? String(editingTarget.target_juz) : ""} />
            </label>
            <label>
              Target tanggal
              <input name="target_date" type="date" defaultValue={editingTarget?.target_date ? String(editingTarget.target_date).slice(0, 10) : ""} />
            </label>

            <div className="formActions">
              <button className="primary">{editingTarget ? "Perbarui target" : "Simpan target"}</button>
              {editingTarget && (
                <button className="ghost dark" type="button" onClick={() => setEditingTarget(null)}>
                  Batal
                </button>
              )}
            </div>
          </form>

          <div className="compactList">
            {targets.slice(0, 8).map(target => (
              <div key={target.id}>
                <span>
                  {students.find(student => student.id === target.student_id)?.full_name ||
                    target.student_id}
                </span>
                <strong>{target.target_juz} Juz</strong>
                <button className="ghost small dark" type="button" onClick={() => setEditingTarget(target)}>
                  Edit
                </button>
              </div>
            ))}
          </div>
        </Card>
      </div>

      <Card title="Riwayat setoran">
        <DataTable
          loading={entriesQuery.isPending}
          rows={entries}
          columns={[
            {key: "date", label: "Tanggal"},
            {
              key: "student_id",
              label: "Santri",
              render: row =>
                students.find(student => student.id === row.student_id)?.full_name ||
                row.student_id,
            },
            {key: "surah", label: "Surah"},
            {
              key: "activity_type",
              label: "Aktivitas",
              render: row => <Pill tone="info">{row.activity_type}</Pill>,
            },
            {
              key: "ayah_start",
              label: "Ayat",
              render: row => `${row.ayah_start}-${row.ayah_end}`,
            },
            {key: "score", label: "Nilai"},
            {key: "teacher_note", label: "Catatan"},
          ]}
        />
      </Card>
    </>
  );
}
