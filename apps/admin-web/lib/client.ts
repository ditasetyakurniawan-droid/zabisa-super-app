export type Envelope<T> =
  | {data: T; error: null}
  | {data?: never; error: {code?: string; message: string; details?: unknown; trace_id?: string}};

type ParsedEnvelope = {
  data?: unknown;
  error?: {
    message?: string;
  } | null;
};

export async function api<T>(path: string, init: RequestInit = {}) {
  const res = await fetch(`/api/backend${path}`, {
    ...init,
    headers: {"Content-Type": "application/json", ...(init.headers || {})},
    cache: "no-store",
  });

  const text = await res.text();
  let body: ParsedEnvelope = {};

  try {
    body = text ? (JSON.parse(text) as ParsedEnvelope) : {data: null, error: null};
  } catch {
    body = {error: {message: text || `HTTP ${res.status}`}};
  }

  if (!res.ok || body.error) {
    throw new Error(body.error?.message || `Request failed (${res.status})`);
  }

  return body.data as T;
}

export async function login(email: string, password: string) {
  const res = await fetch("/api/auth/login", {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({email, password, device_id: "admin-web"}),
  });
  const body = (await res.json()) as ParsedEnvelope;
  if (!res.ok || body.error) throw new Error(body.error?.message || "Login failed");
  return body.data;
}

export async function logout() {
  const res = await fetch("/api/auth/logout", {method: "POST"});
  if (!res.ok) throw new Error(`Logout failed (${res.status})`);
}

export const money = (value: number | string | null | undefined) =>
  new Intl.NumberFormat("id-ID", {
    style: "currency",
    currency: "IDR",
    maximumFractionDigits: 0,
  }).format(Number(value || 0));

export const dateTime = (value: unknown) =>
  value
    ? new Intl.DateTimeFormat("id-ID", {
        dateStyle: "medium",
        timeStyle: "short",
      }).format(new Date(String(value)))
    : "-";
