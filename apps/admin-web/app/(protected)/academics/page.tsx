"use client";

import {FormEvent, useState} from "react";
import DataTable from "../../../components/DataTable";
import {Card, PageHeader, Pill} from "../../../components/Page";
import {api, dateTime} from "../../../lib/client";
import {queryErrorMessage, useApiQuery, useRefreshApi} from "../../../lib/query";
import {can, permissions} from "../../../lib/rbac";
import {useSessionUser} from "../../../lib/session";
import type {AcademicReport, Grade, Student, Subject} from "../../../lib/types";

export default function AcademicsPage() {
  const studentsQuery = useApiQuery<Student[]>("/v1/admin/students");
  const subjectsQuery = useApiQuery<Subject[]>("/v1/admin/subjects");
  const gradesQuery = useApiQuery<Grade[]>("/v1/admin/grades");
  const reportsQuery = useApiQuery<AcademicReport[]>("/v1/admin/reports");
  const sessionQuery = useSessionUser();
  const refresh = useRefreshApi();
  const [message, setMessage] = useState("");
  const [editingSubject, setEditingSubject] = useState<Subject | null>(null);
  const [editingGrade, setEditingGrade] = useState<Grade | null>(null);

  const students = studentsQuery.data ?? [];
  const subjects = subjectsQuery.data ?? [];
  const activeSubjects = subjects.filter(subject => subject.active !== false);
  const grades = gradesQuery.data ?? [];
  const reports = reportsQuery.data ?? [];
  const canWrite = sessionQuery.data ? can(sessionQuery.data.role, permissions.academicsWrite) : false;
  const canPublish = sessionQuery.data ? can(sessionQuery.data.role, permissions.academicsPublish) : false;

  const errorMessage =
    message ||
    queryErrorMessage(
      studentsQuery.error,
      subjectsQuery.error,
      gradesQuery.error,
      reportsQuery.error,
      sessionQuery.error,
    );

  async function saveSubject(event: FormEvent<HTMLFormElement>) {
    if (!canWrite) { setMessage("Role Anda hanya memiliki akses baca akademik."); return; }
    event.preventDefault();
    const formEl = event.currentTarget;
    const form = new FormData(formEl);
    const payload = {
      code: form.get("code"),
      name: form.get("name"),
      category: form.get("category"),
      active: form.get("active") === "on",
    };

    try {
      await api(
        editingSubject ? `/v1/admin/subjects/${editingSubject.id}` : "/v1/admin/subjects",
        {
          method: editingSubject ? "PATCH" : "POST",
          body: JSON.stringify(
            editingSubject ? payload : {code: payload.code, name: payload.name, category: payload.category},
          ),
        },
      );
      formEl.reset();
      setEditingSubject(null);
      setMessage(editingSubject ? "Mata pelajaran diperbarui." : "Mata pelajaran tersimpan.");
      await refresh("/v1/admin/subjects");
    } catch (error) {
      setMessage((error as Error).message);
    }
  }

  async function saveGrade(event: FormEvent<HTMLFormElement>) {
    if (!canWrite) { setMessage("Role Anda hanya memiliki akses baca akademik."); return; }
    event.preventDefault();
    const formEl = event.currentTarget;
    const form = new FormData(formEl);
    const publishNow = form.get("published") === "on";
    const payload = {
      student_id: form.get("student_id"),
      subject_id: form.get("subject_id"),
      academic_year: form.get("academic_year"),
      semester: form.get("semester"),
      assessment_type: form.get("assessment_type"),
      score: form.get("score") ? Number(form.get("score")) : null,
      grade: form.get("grade"),
      teacher_note: form.get("teacher_note"),
      published: editingGrade ? false : publishNow,
    };

    try {
      if (editingGrade) {
        await api(`/v1/admin/grades/${editingGrade.id}`, {
          method: "PATCH",
          body: JSON.stringify(payload),
        });
        if (publishNow) {
          await api(`/v1/admin/grades/${editingGrade.id}/publish`, {method: "PATCH"});
        }
      } else {
        await api("/v1/grades", {method: "POST", body: JSON.stringify(payload)});
      }
      formEl.reset();
      setEditingGrade(null);
      setMessage(publishNow ? "Nilai tersimpan dan dipublikasikan." : editingGrade ? "Draft nilai diperbarui." : "Nilai tersimpan sebagai draft.");
      await refresh("/v1/admin/grades");
    } catch (error) {
      setMessage((error as Error).message);
    }
  }

  async function publishGrade(id: string) {
    if (!canPublish) { setMessage("Role Anda tidak memiliki permission publish."); return; }
    if (!confirm("Publikasikan nilai ini ke wali? Nilai yang sudah published tidak diedit melalui form draft.")) return;
    try {
      await api(`/v1/admin/grades/${id}/publish`, {method: "PATCH"});
      setMessage("Nilai dipublikasikan dan event notifikasi dibuat.");
      await refresh("/v1/admin/grades");
    } catch (error) {
      setMessage((error as Error).message);
    }
  }

  async function createReport(event: FormEvent<HTMLFormElement>) {
    if (!canWrite) { setMessage("Role Anda hanya memiliki akses baca akademik."); return; }
    event.preventDefault();
    const formEl = event.currentTarget;
    const form = new FormData(formEl);

    try {
      await api("/v1/admin/reports", {
        method: "POST",
        body: JSON.stringify(Object.fromEntries(form)),
      });
      formEl.reset();
      setMessage("Report draft dibuat.");
      await refresh("/v1/admin/reports");
    } catch (error) {
      setMessage((error as Error).message);
    }
  }

  async function publishReport(id: string) {
    if (!canPublish) { setMessage("Role Anda tidak memiliki permission publish."); return; }
    if (!confirm("Publikasikan report ini ke wali?")) return;
    try {
      await api(`/v1/admin/reports/${id}/publish`, {method: "PATCH"});
      setMessage("Report dipublikasikan dan event notifikasi dibuat.");
      await refresh("/v1/admin/reports");
    } catch (error) {
      setMessage((error as Error).message);
    }
  }

  return (
    <>
      <PageHeader
        title="Akademik & Report"
        description="Subject configurable, draft nilai, publish terkontrol, dan report lifecycle. Published grade diperlakukan immutable sampai correction workflow + audit hardening tersedia."
      />

      {errorMessage && (
        <div role="status" aria-live="polite" className={/tersimpan|dibuat|diperbarui|dipublikasikan/.test(errorMessage) ? "alert success" : "alert error"}>
          {errorMessage}
        </div>
      )}

      <div className="split">
        <Card title={editingSubject ? "Edit mata pelajaran" : "Master mata pelajaran"}>
          {canWrite ? (
          <form key={editingSubject?.id || "new-subject"} className="formGrid" onSubmit={saveSubject}>
            <label>
              Kode
              <input name="code" required defaultValue={editingSubject?.code || ""} />
            </label>
            <label>
              Nama
              <input name="name" required defaultValue={editingSubject?.name || ""} />
            </label>
            <label>
              Kategori
              <select name="category" defaultValue={editingSubject?.category || "RELIGIOUS"}>
                <option value="RELIGIOUS">Keagamaan</option>
                <option value="ACADEMIC">Akademik</option>
                <option value="OTHER">Lainnya</option>
              </select>
            </label>
            {editingSubject && (
              <label className="check">
                <input name="active" type="checkbox" defaultChecked={editingSubject.active !== false} /> Aktif
              </label>
            )}
            <div className="formActions">
              <button className="primary">{editingSubject ? "Perbarui subject" : "Simpan subject"}</button>
              {editingSubject && (
                <button className="ghost dark" type="button" onClick={() => setEditingSubject(null)}>Batal</button>
              )}
            </div>
          </form>
          ) : (
            <div className="permissionInfo"><strong>Mode read-only</strong><p>Role Anda dapat melihat mata pelajaran tetapi tidak dapat mengubah master akademik.</p></div>
          )}
          <DataTable
            rows={subjects}
            loading={subjectsQuery.isPending}
            columns={[
              {key: "code", label: "Kode"},
              {key: "name", label: "Nama"},
              {key: "category", label: "Kategori"},
              {key: "active", label: "Status", render: row => <Pill tone={row.active !== false ? "ok" : "warn"}>{row.active !== false ? "ACTIVE" : "INACTIVE"}</Pill>},
              ...(canWrite ? [{key: "action", label: "Aksi", render: (row: Subject) => <button className="ghost small dark" onClick={() => setEditingSubject(row)}>Edit</button>}] : []),
            ]}
          />
        </Card>

        <Card title={editingGrade ? "Edit draft nilai" : "Input nilai"}>
          {canWrite ? (
          <form key={editingGrade?.id || "new-grade"} className="formGrid" onSubmit={saveGrade}>
            <label>
              Santri
              <select
                name="student_id"
                required
                defaultValue={editingGrade?.student_id || ""}
                disabled={studentsQuery.isPending}
              >
                <option value="">{studentsQuery.isPending ? "Memuat santri..." : "Pilih..."}</option>
                {students.map(student => <option key={student.id} value={student.id}>{student.full_name}</option>)}
              </select>
            </label>
            <label>
              Mata pelajaran
              <select
                name="subject_id"
                required
                defaultValue={editingGrade?.subject_id || ""}
                disabled={subjectsQuery.isPending}
              >
                <option value="">{subjectsQuery.isPending ? "Memuat mata pelajaran..." : "Pilih..."}</option>
                {activeSubjects.map(subject => <option key={subject.id} value={subject.id}>{subject.code} · {subject.name}</option>)}
              </select>
            </label>
            <div className="two">
              <label>Tahun ajaran<input name="academic_year" defaultValue={editingGrade?.academic_year || "2026/2027"} required /></label>
              <label>Semester<input name="semester" defaultValue={editingGrade?.semester || "1"} required /></label>
            </div>
            <label>Jenis assessment<input name="assessment_type" placeholder="UTS / UAS / Assignment" defaultValue={editingGrade?.assessment_type || ""} required /></label>
            <div className="two">
              <label>Score<input name="score" type="number" step="0.01" min="0" max="100" defaultValue={editingGrade?.score == null ? "" : String(editingGrade.score)} /></label>
              <label>Grade<input name="grade" defaultValue={editingGrade?.grade || ""} /></label>
            </div>
            <label>Catatan guru<textarea name="teacher_note" defaultValue={editingGrade?.teacher_note || ""} /></label>
            <label className="check"><input name="published" type="checkbox" /> {editingGrade ? "Simpan lalu publish" : "Publish sekarang"}</label>
            <div className="formActions">
              <button className="primary">{editingGrade ? "Perbarui draft" : "Simpan nilai"}</button>
              {editingGrade && <button className="ghost dark" type="button" onClick={() => setEditingGrade(null)}>Batal</button>}
            </div>
          </form>
          ) : (
            <div className="permissionInfo"><strong>Mode read-only</strong><p>Role Anda tidak mempunyai permission untuk input atau mengubah nilai.</p></div>
          )}
        </Card>
      </div>

      <div className="split">
        <Card title="Buat report">
          {canWrite ? (
          <form className="formGrid" onSubmit={createReport}>
            <label>Santri<select name="student_id" required defaultValue=""><option value="">Pilih...</option>{students.map(student => <option key={student.id} value={student.id}>{student.full_name}</option>)}</select></label>
            <label>Tahun ajaran<input name="academic_year" defaultValue="2026/2027" required /></label>
            <label>Semester<input name="semester" defaultValue="1" required /></label>
            <label>Tipe report<select name="report_type" defaultValue="TAHFIDZ"><option value="TAHFIDZ">Tahfidz</option><option value="ISLAMIC_STUDIES">Islamic Studies</option><option value="ACADEMIC">Academic</option></select></label>
            <button className="primary">Buat draft report</button>
          </form>
          ) : (
            <div className="permissionInfo"><strong>Mode read-only</strong><p>Role Anda tidak dapat membuat report.</p></div>
          )}
        </Card>

        <Card title="Report">
          <DataTable
            loading={reportsQuery.isPending}
            rows={reports}
            columns={[
              {key: "student_id", label: "Santri", render: row => students.find(student => student.id === row.student_id)?.full_name || row.student_id},
              {key: "report_type", label: "Tipe"},
              {key: "semester", label: "Semester"},
              {key: "status", label: "Status", render: row => <Pill tone={row.status === "PUBLISHED" ? "ok" : "warn"}>{row.status}</Pill>},
              {key: "action", label: "Aksi", render: row => row.status !== "PUBLISHED" && canPublish ? <button className="small primary" onClick={() => publishReport(row.id)}>Publish</button> : "-"},
            ]}
          />
        </Card>
      </div>

      <Card title="Nilai terbaru">
        <DataTable
          loading={gradesQuery.isPending}
          rows={grades}
          columns={[
            {key: "created_at", label: "Waktu", render: row => dateTime(row.created_at)},
            {key: "student_id", label: "Santri", render: row => students.find(student => student.id === row.student_id)?.full_name || row.student_id},
            {key: "subject_name", label: "Mapel"},
            {key: "assessment_type", label: "Assessment"},
            {key: "score", label: "Score"},
            {key: "grade", label: "Grade"},
            {key: "published", label: "Status", render: row => <Pill tone={row.published ? "ok" : "warn"}>{row.published ? "Published" : "Draft"}</Pill>},
            {key: "action", label: "Aksi", render: row => row.published ? <span className="muted">Immutable</span> : canWrite ? <div className="formActions"><button className="ghost small dark" onClick={() => setEditingGrade(row)}>Edit</button>{canPublish && <button className="small primary" onClick={() => publishGrade(row.id)}>Publish</button>}</div> : <span className="muted">Read only</span>},
          ]}
        />
      </Card>
    </>
  );
}
