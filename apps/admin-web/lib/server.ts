export const backendURL = () => (process.env.BACKEND_INTERNAL_URL || "http://api-gateway:8080").replace(/\/$/, "");
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
