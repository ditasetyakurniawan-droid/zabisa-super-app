"use client";

import EditableResourcePage from "../../../components/EditableResourcePage";
import {Pill} from "../../../components/Page";
import type {RowRecord} from "../../../lib/types";

type ContentRow = RowRecord & {
  id: string;
  type: string;
  title: string;
  slug: string;
  summary?: string | null;
  body?: string | null;
  image_url?: string | null;
  published: boolean;
};

const types = [
  "PROFILE",
  "PROGRAM",
  "NEWS",
  "ARTICLE",
  "ANNOUNCEMENT",
  "EMERGENCY",
  "GALLERY",
  "BANNER",
];

export default function ContentPage() {
  return (
    <EditableResourcePage<ContentRow>
      title="Content Management"
      description="Buat, edit, publish, dan unpublish konten yang dikonsumsi aplikasi mobile. Tidak ada konten production yang di-hardcode di mobile."
      listPath="/v1/admin/content"
      createPath="/v1/admin/content"
      updatePath={row => `/v1/admin/content/${row.id}`}
      createLabel="Simpan konten"
      editLabel="Perbarui konten"
      fields={[
        {
          name: "type",
          label: "Tipe",
          type: "select",
          required: true,
          options: types.map(type => ({label: type, value: type})),
        },
        {name: "title", label: "Judul", required: true},
        {name: "slug", label: "Slug", required: true},
        {name: "summary", label: "Ringkasan", type: "textarea"},
        {name: "body", label: "Isi", type: "textarea"},
        {name: "image_url", label: "URL gambar"},
        {
          name: "published",
          label: "Publikasikan",
          type: "checkbox",
          valueType: "boolean",
        },
      ]}
      columns={[
        {key: "title", label: "Judul"},
        {
          key: "type",
          label: "Tipe",
          render: row => <Pill tone="info">{row.type}</Pill>,
        },
        {key: "slug", label: "Slug"},
        {
          key: "published",
          label: "Status",
          render: row => (
            <Pill tone={row.published ? "ok" : "warn"}>
              {row.published ? "Published" : "Draft"}
            </Pill>
          ),
        },
      ]}
    />
  );
}
