"use client";

import {SyntheticEvent, useState} from "react";
import DataTable, {type Column} from "./DataTable";
import {Card, PageHeader} from "./Page";
import {api} from "../lib/client";
import {queryErrorMessage, useApiQuery, useRefreshApi} from "../lib/query";
import type {RowRecord} from "../lib/types";

export type Field = {
  name: string;
  label: string;
  type?: "text" | "email" | "password" | "number" | "date" | "datetime-local" | "textarea" | "select" | "checkbox";
  required?: boolean;
  options?: {label: string; value: string}[];
  valueType?: "number" | "iso" | "boolean";
  placeholder?: string;
};

function formValue(field: Field, form: FormData): unknown {
  const raw = field.type === "checkbox" ? form.get(field.name) === "on" : form.get(field.name);

  if (field.valueType === "number") return raw === "" ? null : Number(raw);
  if (field.valueType === "iso") return raw ? new Date(String(raw)).toISOString() : null;
  if (field.valueType === "boolean") return Boolean(raw);

  return raw;
}

function resourceInput(field: Field, initial?: Record<string, string>) {
  if (field.type === "textarea") {
    return <textarea name={field.name} required={field.required} placeholder={field.placeholder} />;
  }
  if (field.type === "select") {
    return (
      <select name={field.name} required={field.required} defaultValue={initial?.[field.name] || ""}>
        <option value="">Pilih...</option>
        {field.options?.map(option => <option key={option.value} value={option.value}>{option.label}</option>)}
      </select>
    );
  }
  if (field.type === "checkbox") {
    return <input name={field.name} type="checkbox" defaultChecked={initial?.[field.name] === "true"} />;
  }
  return <input name={field.name} type={field.type || "text"} required={field.required} placeholder={field.placeholder} defaultValue={initial?.[field.name] || ""} />;
}

export default function ResourcePage<T extends RowRecord>({
  title,
  description,
  listPath,
  createPath,
  fields,
  columns,
  createLabel = "Simpan",
  initial,
}: {
  title: string;
  description: string;
  listPath: string;
  createPath: string;
  fields: Field[];
  columns: Column<T>[];
  createLabel?: string;
  initial?: Record<string, string>;
}) {
  const query = useApiQuery<T[]>(listPath);
  const refresh = useRefreshApi();
  const [message, setMessage] = useState("");

  const rows = query.data ?? [];
  const errorMessage = message || queryErrorMessage(query.error);

  async function submit(event: SyntheticEvent<HTMLFormElement>) {
    event.preventDefault();
    setMessage("");

    const formEl = event.currentTarget;
    const form = new FormData(formEl);
    const payload: Record<string, unknown> = {};

    for (const field of fields) payload[field.name] = formValue(field, form);

    try {
      await api(createPath, {method: "POST", body: JSON.stringify(payload)});
      formEl.reset();
      setMessage("Data tersimpan.");
      await refresh(listPath);
    } catch (error) {
      setMessage((error as Error).message);
    }
  }

  return (
    <>
      <PageHeader title={title} description={description} />
      {errorMessage && (
        <div className={errorMessage.includes("tersimpan") ? "alert success" : "alert error"}>
          {errorMessage}
        </div>
      )}
      <div className="split">
        <Card title="Tambah baru">
          <form className="formGrid" onSubmit={submit}>
            {fields.map(field => (
              <label key={field.name}>
                {field.label}
                {resourceInput(field, initial)}
              </label>
            ))}
            <button className="primary" type="submit">
              {createLabel}
            </button>
          </form>
        </Card>

        <Card title="Data terbaru" className="wide">
          <DataTable
            rows={rows}
            columns={columns}
            loading={query.isPending && !query.data}
          />
        </Card>
      </div>
    </>
  );
}
