const plaintextBackendHosts = new Set([
  "api-gateway",
  "api-gateway.zabisa-app.svc",
  "api-gateway.zabisa-app.svc.cluster.local",
  "localhost",
  "127.0.0.1",
]);

export function backendURL() {
  const configured = process.env.BACKEND_INTERNAL_URL?.trim();
  if (!configured) throw new Error("BACKEND_INTERNAL_URL is required");

  let parsed: URL;
  try {
    parsed = new URL(configured);
  } catch {
    throw new Error("BACKEND_INTERNAL_URL must be an absolute URL");
  }

  const encrypted = parsed.protocol === "https:";
  const approvedInternalPlaintext =
    parsed.protocol === "http:" && plaintextBackendHosts.has(parsed.hostname);
  if (!encrypted && !approvedInternalPlaintext) {
    throw new Error("BACKEND_INTERNAL_URL must use HTTPS outside approved internal hosts");
  }

  return parsed.toString().replace(/\/$/, "");
}
export const accessCookie = "zabisa_at";
export const refreshCookie = "zabisa_rt";

function secureCookies() {
  const configured = process.env.ZABISA_COOKIE_SECURE?.trim().toLowerCase();
  if (configured === "true") return true;
  if (configured === "false") return false;
  return process.env.NODE_ENV === "production";
}

export const cookieOptions = (maxAge: number) => ({
  httpOnly: true,
  secure: secureCookies(),
  sameSite: "lax" as const,
  path: "/",
  maxAge,
});
