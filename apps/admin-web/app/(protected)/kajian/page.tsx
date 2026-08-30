"use client";

import EditableResourcePage from "../../../components/EditableResourcePage";
import {Pill} from "../../../components/Page";
import {dateTime} from "../../../lib/client";
import type {RowRecord} from "../../../lib/types";

type KajianRow = RowRecord & {
  id: string;
  title: string;
  slug: string;
  description?: string;
  speaker?: string | null;
  start_at?: string | null;
  location?: string | null;
  map_url?: string | null;
  live_url?: string | null;
  poster_url?: string | null;
  published: boolean;
};

export default function KajianPage() {
  return (
    <EditableResourcePage<KajianRow>
      title="Kajian & Event"
      description="Create/edit/publish kajian. Transisi draft ke published memicu transactional outbox untuk notifikasi dan data langsung tersedia di mobile."
      listPath="/v1/admin/kajian"
      createPath="/v1/admin/kajian"
      updatePath={row => `/v1/admin/kajian/${row.id}`}
      createLabel="Simpan kajian"
      editLabel="Perbarui kajian"
      fields={[
        {name: "title", label: "Judul", required: true},
        {name: "slug", label: "Slug", required: true},
        {name: "description", label: "Deskripsi", type: "textarea", required: true},
        {name: "speaker", label: "Pemateri"},
        {
          name: "start_at",
          label: "Mulai",
          type: "datetime-local",
          valueType: "iso",
          required: true,
        },
        {name: "location", label: "Lokasi"},
        {name: "map_url", label: "Google Maps URL"},
        {name: "live_url", label: "Live stream URL"},
        {name: "poster_url", label: "Poster URL"},
        {
          name: "published",
          label: "Publikasikan",
          type: "checkbox",
          valueType: "boolean",
        },
      ]}
      columns={[
        {key: "title", label: "Kajian"},
        {key: "slug", label: "Slug"},
        {key: "speaker", label: "Pemateri"},
        {
          key: "start_at",
          label: "Jadwal",
          render: row => dateTime(row.start_at),
        },
        {key: "location", label: "Lokasi"},
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
