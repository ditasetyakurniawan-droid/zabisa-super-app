"use client";

import DataTable from "../../../components/DataTable";
import {Card, PageHeader, Pill} from "../../../components/Page";
import {dateTime} from "../../../lib/client";
import {queryErrorMessage, useApiQuery} from "../../../lib/query";
import type {RowRecord} from "../../../lib/types";

type AuditRow = RowRecord & {
  id?: string;
  created_at?: string;
  action: string;
  resource?: string;
  resource_id?: string;
  source_service?: string;
  actor_id?: string;
  before?: unknown;
  after?: unknown;
  request_id?: string;
  trace_id?: string;
};

function compact(value: unknown) {
  if (value === null || value === undefined || value === "") return "-";
  const serialized = typeof value === "string" ? value : JSON.stringify(value);
  return serialized.length > 120 ? `${serialized.slice(0, 117)}...` : serialized;
}

export default function AuditPage() {
  const query = useApiQuery<AuditRow[]>("/v1/admin/audit-logs");
  const rows = query.data ?? [];
  const errorMessage = queryErrorMessage(query.error);

  return (
    <>
      <PageHeader
        title="Audit Log"
        description="Append-only audit lintas bounded-context untuk operasi sensitif. Audit dikirim melalui transactional outbox dan tidak mempunyai endpoint update/delete untuk admin normal."
      />
      {errorMessage && <div className="alert error">{errorMessage}</div>}
      <Card>
        <DataTable
          loading={query.isPending}
          rows={rows}
          columns={[
            {key: "created_at", label: "Waktu", render: row => dateTime(row.created_at)},
            {
              key: "action",
              label: "Aksi",
              render: row => <Pill tone="info">{row.action}</Pill>,
            },
            {key: "resource", label: "Resource"},
            {key: "resource_id", label: "ID"},
            {key: "source_service", label: "Service"},
            {key: "actor_id", label: "Actor"},
            {
              key: "before",
              label: "Before",
              render: row => <code className="auditJson">{compact(row.before)}</code>,
            },
            {
              key: "after",
              label: "After",
              render: row => <code className="auditJson">{compact(row.after)}</code>,
            },
            {key: "request_id", label: "Request ID"},
            {key: "trace_id", label: "Trace ID"},
          ]}
        />
      </Card>
    </>
  );
}
