import {defineConfig} from "@playwright/test";

const executablePath = process.env.ZABISA_CHROME_BIN || undefined;

export default defineConfig({
  testDir: "./e2e",
  timeout: 90_000,
  expect: {timeout: 10_000},
  fullyParallel: false,
  workers: 1,
  retries: 1,
  reporter: [["list"]],
  use: {
    baseURL: process.env.ZABISA_ADMIN_BASE_URL || "http://localhost:3001",
    headless: true,
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
    video: "off",
    launchOptions: executablePath ? {executablePath} : undefined,
  },
});
