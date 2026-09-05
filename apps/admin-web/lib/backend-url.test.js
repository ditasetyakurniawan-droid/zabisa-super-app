const {describe, expect, it} = require("@jest/globals");
const {resolveBackendURL} = require("./backend-url");

describe("resolveBackendURL", () => {
  it.each([
    [undefined, "BACKEND_INTERNAL_URL is required"],
    ["   ", "BACKEND_INTERNAL_URL is required"],
    ["not-a-url", "BACKEND_INTERNAL_URL must be an absolute URL"],
    ["http://example.com", "BACKEND_INTERNAL_URL must use HTTPS outside approved internal hosts"],
    ["ftp://api-gateway", "BACKEND_INTERNAL_URL must use HTTPS outside approved internal hosts"],
  ])("rejects unsafe configuration %p", (configured, message) => {
    expect(() => resolveBackendURL(configured)).toThrow(message);
  });

  it.each([
    ["https://example.com/", "https://example.com"],
    ["http://api-gateway:8080/", "http://api-gateway:8080"],
    ["http://api-gateway.zabisa-app.svc/", "http://api-gateway.zabisa-app.svc"],
    ["http://api-gateway.zabisa-app.svc.cluster.local/", "http://api-gateway.zabisa-app.svc.cluster.local"],
    ["http://localhost:8080/", "http://localhost:8080"],
    ["http://127.0.0.1:8080/", "http://127.0.0.1:8080"],
  ])("accepts reviewed backend %s", (configured, expected) => {
    expect(resolveBackendURL(configured)).toBe(expected);
  });
});
