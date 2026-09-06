"use client";

import {SyntheticEvent, useState} from "react";
import DataTable from "../../../components/DataTable";
import {Card, PageHeader, Pill} from "../../../components/Page";
import {api} from "../../../lib/client";
import {queryErrorMessage, useApiQuery, useRefreshApi} from "../../../lib/query";
import type {AttendanceRow, Student} from "../../../lib/types";

function studentOptionLabel(isPending: boolean, count: number) {
  if (isPending) return "Memuat santri...";
  if (count === 0) return "Belum ada santri tersedia";
  return "Pilih...";
}

function studentHelp(isPending: boolean, count: number) {
  if (isPending) return "Daftar santri sedang dimuat.";
  if (count === 0) return "Belum ada santri yang dapat dipilih. Tambahkan data santri terlebih dahulu.";
  return `${count} santri tersedia.`;
}

function attendanceTone(status: string) {
  if (status === "PRESENT") return "ok" as const;
  if (status === "ABSENT") return "danger" as const;
  return "warn" as const;
}

export default function AttendancePage() {
  const studentsQuery = useApiQuery<Student[]>("/v1/admin/students");
  const attendanceQuery = useApiQuery<AttendanceRow[]>("/v1/admin/attendance");
  const refresh = useRefreshApi();
  const [message, setMessage] = useState("");

  const students = studentsQuery.data ?? [];
  const rows = attendanceQuery.data ?? [];
  const errorMessage =
    message || queryErrorMessage(studentsQuery.error, attendanceQuery.error);

  async function submit(event: SyntheticEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = new FormData(event.currentTarget);

    try {
      await api("/v1/admin/attendance", {
        method: "POST",
        body: JSON.stringify({
          student_id: form.get("student_id"),
          date: form.get("date"),
          status: form.get("status"),
          note: form.get("note"),
        }),
      });
      setMessage("Kehadiran tersimpan.");
      await refresh("/v1/admin/attendance");
    } catch (error) {
      setMessage((error as Error).message);
    }
  }

  return (
    <>
      <PageHeader
        title="Kehadiran"
        description="Monitoring kehadiran santri dengan terminologi status yang dapat dikembangkan tanpa mengubah akses wali."
      />

      {errorMessage && (
        <div
          role="status"
          aria-live="polite"
          className={errorMessage.includes("tersimpan") ? "alert success" : "alert error"}
        >
          {errorMessage}
        </div>
      )}

      <div className="split">
        <Card title="Catat kehadiran">
          <form className="formGrid" onSubmit={submit}>
            <div>
              <label htmlFor="attendance-student">Santri</label>
              <select
                id="attendance-student"
                name="student_id"
                required
                defaultValue=""
                disabled={studentsQuery.isPending || students.length === 0}
                aria-describedby="attendance-student-help"
              >
                <option value="">
                  {studentOptionLabel(studentsQuery.isPending, students.length)}
                </option>
                {students.map(student => (
                  <option key={student.id} value={student.id}>
                    {student.student_no} · {student.full_name}
                  </option>
                ))}
              </select>
              <p id="attendance-student-help" className="hint">
                {studentHelp(studentsQuery.isPending, students.length)}
              </p>
            </div>
            <div>
              <label htmlFor="attendance-date">Tanggal</label>
              <input id="attendance-date" name="date" type="date" required />
            </div>
            <div>
              <label htmlFor="attendance-status">Status</label>
              <select id="attendance-status" name="status" defaultValue="PRESENT">
                <option value="PRESENT">Hadir</option>
                <option value="SICK">Sakit</option>
                <option value="PERMITTED">Izin</option>
                <option value="ABSENT">Alpa</option>
                <option value="OTHER">Lainnya</option>
              </select>
            </div>
            <div>
              <label htmlFor="attendance-note">Catatan</label>
              <textarea id="attendance-note" name="note" />
            </div>
            <button
              className="primary"
              disabled={studentsQuery.isPending || students.length === 0}
            >
              Simpan kehadiran
            </button>
          </form>
        </Card>

        <Card title="Ringkasan">
          <div className="statsMini">
            <div>
              <strong>{rows.filter(row => row.status === "PRESENT").length}</strong>
              <span>Hadir</span>
            </div>
            <div>
              <strong>{rows.filter(row => row.status === "SICK").length}</strong>
              <span>Sakit</span>
            </div>
            <div>
              <strong>{rows.filter(row => row.status === "PERMITTED").length}</strong>
              <span>Izin</span>
            </div>
            <div>
              <strong>{rows.filter(row => row.status === "ABSENT").length}</strong>
              <span>Alpa</span>
            </div>
          </div>
        </Card>
      </div>

      <Card title="Riwayat">
        <DataTable
          loading={attendanceQuery.isPending}
          rows={rows}
          columns={[
            {key: "date", label: "Tanggal"},
            {key: "student_name", label: "Santri"},
            {
              key: "status",
              label: "Status",
              render: row => (
                <Pill
                  tone={attendanceTone(row.status)}
                >
                  {row.status}
                </Pill>
              ),
            },
            {key: "note", label: "Catatan"},
          ]}
        />
      </Card>
    </>
  );
}
