const plaintextBackendHosts = new Set([
  "api-gateway",
  "api-gateway.zabisa-app.svc",
  "api-gateway.zabisa-app.svc.cluster.local",
  "localhost",
  "127.0.0.1",
]);

function resolveBackendURL(configured) {
  const value = configured?.trim();
  if (!value) throw new Error("BACKEND_INTERNAL_URL is required");

  let parsed;
  try {
    parsed = new URL(value);
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

module.exports = {resolveBackendURL};
