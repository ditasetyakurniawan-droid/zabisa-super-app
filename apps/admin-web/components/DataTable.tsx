"use client";

import {Empty} from "./Page";
import type {RowRecord} from "../lib/types";

export type Column<T> = {
  key: string;
  label: string;
  render?: (row: T) => React.ReactNode;
};

export default function DataTable<T extends RowRecord>({
  rows,
  columns,
  loading,
  keyField = "id",
}: {
  rows: T[];
  columns: Column<T>[];
  loading?: boolean;
  keyField?: string;
}) {
  if (loading) {
    return (
      <div className="skeletonList">
        <i />
        <i />
        <i />
      </div>
    );
  }

  if (!rows.length) return <Empty />;

  return (
    <div className="tableWrap">
      <table>
        <thead>
          <tr>
            {columns.map(column => (
              <th key={column.key}>{column.label}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row, index) => (
            <tr key={String(row[keyField] ?? index)}>
              {columns.map(column => (
                <td key={column.key}>
                  {column.render ? column.render(row) : String(row[column.key] ?? "-")}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
