"use client";

import {SyntheticEvent, useMemo, useState} from "react";
import DataTable, {type Column} from "./DataTable";
import {Card, PageHeader} from "./Page";
import {api} from "../lib/client";
import {queryErrorMessage, useApiQuery, useRefreshApi} from "../lib/query";
import type {RowRecord} from "../lib/types";
import type {Field} from "./ResourcePage";

function dateInput(value: unknown) {
  if (!value) return "";
  const date = new Date(String(value));
  if (Number.isNaN(date.getTime())) return "";
  const local = new Date(date.getTime() - date.getTimezoneOffset() * 60_000);
  return local.toISOString().slice(0, 16);
}

function initialValue(row: RowRecord | null, field: Field) {
  if (!row) return "";
  const value = row[field.name];
  if (field.type === "datetime-local") return dateInput(value);
  if (value === null || value === undefined) return "";
  return String(value);
}

function formValue(field: Field, form: FormData): unknown {
  const raw = field.type === "checkbox" ? form.get(field.name) === "on" : form.get(field.name);

  if (field.valueType === "number") return raw === "" ? null : Number(raw);
  if (field.valueType === "iso") return raw ? new Date(String(raw)).toISOString() : null;
  if (field.valueType === "boolean") return Boolean(raw);

  return raw;
}

export default function EditableResourcePage<T extends RowRecord>({
  title,
  description,
  listPath,
  createPath,
  updatePath,
  fields,
  columns,
  createLabel = "Simpan",
  editLabel = "Perbarui",
  canWrite = true,
}: {
  title: string;
  description: string;
  listPath: string;
  createPath: string;
  updatePath: (row: T) => string;
  fields: Field[];
  columns: Column<T>[];
  createLabel?: string;
  editLabel?: string;
  canWrite?: boolean;
}) {
  const query = useApiQuery<T[]>(listPath);
  const refresh = useRefreshApi();
  const [message, setMessage] = useState("");
  const [editing, setEditing] = useState<T | null>(null);

  const rows = query.data ?? [];
  const errorMessage = message || queryErrorMessage(query.error);

  const tableColumns = useMemo<Column<T>[]>(
    () => [
      ...columns,
      ...(canWrite
        ? [{
            key: "__actions",
            label: "Aksi",
            render: (row: T) => (
              <button
                className="ghost small dark"
                type="button"
                onClick={() => {
                  setEditing(row);
                  setMessage("");
                }}
              >
                Edit
              </button>
            ),
          } as Column<T>]
        : []),
    ],
    [canWrite, columns],
  );

  async function submit(event: SyntheticEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!canWrite) {
      setMessage("Role Anda hanya memiliki akses baca untuk data ini.");
      return;
    }
    setMessage("");

    const formEl = event.currentTarget;
    const form = new FormData(formEl);
    const payload: Record<string, unknown> = {};

    for (const field of fields) payload[field.name] = formValue(field, form);

    try {
      await api(editing ? updatePath(editing) : createPath, {
        method: editing ? "PATCH" : "POST",
        body: JSON.stringify(payload),
      });
      setMessage(editing ? "Data diperbarui." : "Data tersimpan.");
      setEditing(null);
      formEl.reset();
      await refresh(listPath);
    } catch (error) {
      setMessage((error as Error).message);
    }
  }

  return (
    <>
      <PageHeader title={title} description={description} />
      {errorMessage && (
        <div
          role="status"
          aria-live="polite"
          className={
            errorMessage.includes("tersimpan") || errorMessage.includes("diperbarui")
              ? "alert success"
              : "alert error"
          }
        >
          {errorMessage}
        </div>
      )}

      <div className="split">
        <Card title={canWrite ? (editing ? "Edit data" : "Tambah baru") : "Akses baca"}>
          {canWrite ? (
          <form
            key={String(editing?.id ?? "new")}
            className="formGrid"
            onSubmit={submit}
          >
            {fields.map(field => (
              <label key={field.name}>
                {field.label}
                {field.type === "textarea" ? (
                  <textarea
                    name={field.name}
                    required={field.required}
                    placeholder={field.placeholder}
                    defaultValue={initialValue(editing, field)}
                  />
                ) : field.type === "select" ? (
                  <select
                    name={field.name}
                    required={field.required}
                    defaultValue={initialValue(editing, field)}
                  >
                    <option value="">Pilih...</option>
                    {field.options?.map(option => (
                      <option key={option.value} value={option.value}>
                        {option.label}
                      </option>
                    ))}
                  </select>
                ) : field.type === "checkbox" ? (
                  <input
                    name={field.name}
                    type="checkbox"
                    defaultChecked={editing ? Boolean(editing[field.name]) : false}
                  />
                ) : (
                  <input
                    name={field.name}
                    type={field.type || "text"}
                    required={field.required}
                    placeholder={field.placeholder}
                    defaultValue={initialValue(editing, field)}
                  />
                )}
              </label>
            ))}
            <div className="formActions">
              <button className="primary" type="submit">
                {editing ? editLabel : createLabel}
              </button>
              {editing && (
                <button
                  className="ghost dark"
                  type="button"
                  onClick={() => {
                    setEditing(null);
                    setMessage("");
                  }}
                >
                  Batal
                </button>
              )}
            </div>
          </form>
          ) : (
            <div className="permissionInfo">
              <strong>Mode read-only</strong>
              <p>Role Anda dapat melihat data ini, tetapi tidak mempunyai permission untuk membuat atau mengubah record.</p>
            </div>
          )}
        </Card>

        <Card title="Data terbaru" className="wide">
          <DataTable
            rows={rows}
            columns={tableColumns}
            loading={query.isPending && !query.data}
          />
        </Card>
      </div>
    </>
  );
}
