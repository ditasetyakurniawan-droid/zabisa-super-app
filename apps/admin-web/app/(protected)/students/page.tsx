"use client";

import EditableResourcePage from "../../../components/EditableResourcePage";
import {Pill} from "../../../components/Page";
import {can, permissions} from "../../../lib/rbac";
import {useSessionUser} from "../../../lib/session";
import type {Student} from "../../../lib/types";

function studentStatusTone(status: string) {
  if (status === "ACTIVE") return "ok" as const;
  if (status === "GRADUATED") return "info" as const;
  return "warn" as const;
}

export default function StudentsPage() {
  const sessionQuery = useSessionUser();
  const canWrite = sessionQuery.data ? can(sessionQuery.data.role, permissions.studentsWrite) : false;

  return (
    <EditableResourcePage<Student>
      title="Data Santri"
      description="Master data santri dengan create/update terkontrol. Data privat tetap dilindungi role dan object-level authorization di backend."
      listPath="/v1/admin/students"
      createPath="/v1/admin/students"
      updatePath={row => `/v1/admin/students/${row.id}`}
      createLabel="Tambah santri"
      editLabel="Perbarui santri"
      canWrite={canWrite}
      fields={[
        {name: "student_no", label: "Nomor santri", required: true},
        {name: "full_name", label: "Nama lengkap", required: true},
        {name: "photo_url", label: "URL foto"},
        {name: "class_name", label: "Kelas"},
        {name: "program_name", label: "Program"},
        {name: "academic_year", label: "Tahun ajaran"},
        {
          name: "status",
          label: "Status",
          type: "select",
          required: true,
          options: [
            {label: "Aktif", value: "ACTIVE"},
            {label: "Tidak aktif", value: "INACTIVE"},
            {label: "Lulus", value: "GRADUATED"},
          ],
        },
      ]}
      columns={[
        {key: "student_no", label: "No. Santri"},
        {key: "full_name", label: "Nama"},
        {key: "class_name", label: "Kelas"},
        {key: "program_name", label: "Program"},
        {key: "academic_year", label: "Tahun ajaran"},
        {
          key: "status",
          label: "Status",
          render: row => (
            <Pill tone={studentStatusTone(row.status)}>
              {row.status}
            </Pill>
          ),
        },
      ]}
    />
  );
}
