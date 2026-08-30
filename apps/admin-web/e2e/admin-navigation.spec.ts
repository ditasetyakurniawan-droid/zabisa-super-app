import {expect, test, type Locator, type Page} from "@playwright/test";

async function login(page: Page) {
  await page.goto("/login", {waitUntil: "domcontentloaded"});
  await page.getByLabel("Email").fill("admin@zabisa.local");
  await page.getByLabel("Password").fill("ChangeMe123!");
  const responsePromise = page.waitForResponse(
    response => response.url().includes("/api/auth/login") && response.request().method() === "POST",
  );
  await page.getByRole("button", {name: "Masuk"}).click();
  const response = await responsePromise;
  expect(response.status(), await response.text()).toBe(200);
  await expect(page).toHaveURL(/\/dashboard/, {timeout: 15_000});
  await expect(page.getByText("Zabisa Operations Console")).toBeVisible();
}

function collectRuntimeFailures(page: Page) {
  const pageErrors: string[] = [];
  const serverErrors: string[] = [];
  page.on("pageerror", error => pageErrors.push(error.message));
  page.on("response", response => {
    if (response.status() >= 500) serverErrors.push(`${response.status()} ${response.url()}`);
  });
  return {pageErrors, serverErrors};
}

async function navigateModule(page: Page, label: string, url: RegExp) {
  const link = page.getByRole("link", {name: label, exact: true});
  await expect(link, `Sidebar link "${label}" must be visible and accessible`).toBeVisible({
    timeout: 10_000,
  });
  await link.click();
  await expect(page, `Navigation "${label}" must resolve to the expected route`).toHaveURL(url, {
    timeout: 15_000,
  });
  await expect(page.locator("main.mainArea")).toBeVisible();
}

async function expectSuccessfulMutation(
  page: Page,
  method: string,
  pathFragment: string,
  action: () => Promise<void>,
) {
  const responsePromise = page.waitForResponse(
    response =>
      response.url().includes(`/api/backend${pathFragment}`) &&
      response.request().method() === method,
  );
  await action();
  const response = await responsePromise;
  const body = await response.text();
  expect(response.status(), `${method} ${pathFragment}: ${body}`).toBeGreaterThanOrEqual(200);
  expect(response.status(), `${method} ${pathFragment}: ${body}`).toBeLessThan(300);
}

async function waitForRealSelectOptions(select: Locator) {
  await expect.poll(
    async () =>
      select
        .locator("option")
        .evaluateAll(nodes =>
          nodes.filter(node => Boolean((node as HTMLOptionElement).value)).length,
        ),
    {timeout: 15_000, message: "Dependent select should load at least one real option"},
  ).toBeGreaterThan(0);
}

test("all SUPER_ADMIN Backoffice modules navigate repeatedly without client/runtime failure", async ({page}) => {
  const failures = collectRuntimeFailures(page);
  await login(page);

  const cycle: Array<[string, RegExp]> = [
    ["Dashboard", /\/dashboard/],
    ["Konten", /\/content/],
    ["Kajian & Event", /\/kajian/],
    ["Donasi", /\/donation/],
    ["Data Santri", /\/students/],
    ["Wali & Linking", /\/guardians/],
    ["Tahfidz", /\/tahfidz/],
    ["Akademik & Report", /\/academics/],
    ["Kehadiran", /\/attendance/],
    ["Notifikasi", /\/notifications/],
    ["User & Access", /\/access/],
    ["Audit Log", /\/audit/],
    ["User & Access", /\/access/],
  ];

  for (let round = 0; round < 3; round += 1) {
    for (const [label, url] of cycle) {
      await navigateModule(page, label, url);
    }
  }

  expect(failures.pageErrors, failures.pageErrors.join("\n")).toEqual([]);
  expect(failures.serverErrors, failures.serverErrors.join("\n")).toEqual([]);
});

test("Data Santri UI create and update matches strict backend contract", async ({page}) => {
  await login(page);
  await page.getByRole("link", {name: "Data Santri", exact: true}).click();
  const suffix = String(Date.now()).slice(-9);
  const studentNo = `E2E-${suffix}`;
  const studentName = `DEVELOPMENT DATA Browser Student ${suffix}`;

  await page.getByLabel("Nomor santri").fill(studentNo);
  await page.getByLabel("Nama lengkap").fill(studentName);
  await page.getByLabel("URL foto").fill("");
  await page.getByLabel("Kelas").fill("Browser A");
  await page.getByLabel("Program").fill("Tahfidz");
  await page.getByLabel("Tahun ajaran").fill("2026/2027");
  await page.getByLabel("Status").selectOption("ACTIVE");
  await expectSuccessfulMutation(page, "POST", "/v1/admin/students", async () => {
    await page.getByRole("button", {name: "Tambah santri"}).click();
  });
  await expect(page.getByText("Data tersimpan.")).toBeVisible();

  const row = page.getByRole("row").filter({hasText: studentNo});
  await expect(row).toContainText(studentName);
  await row.getByRole("button", {name: "Edit"}).click();
  await page.getByLabel("Kelas").fill("Browser Updated");
  await page.getByLabel("Status").selectOption("INACTIVE");
  await expectSuccessfulMutation(page, "PATCH", "/v1/admin/students/", async () => {
    await page.getByRole("button", {name: "Perbarui santri"}).click();
  });
  await expect(page.getByText("Data diperbarui.")).toBeVisible();
  await expect(page.getByRole("row").filter({hasText: studentNo})).toContainText("INACTIVE");
});

test("guardian onboarding screen exposes narrow candidate + staged approval flow", async ({page}) => {
  await login(page);
  await page.getByRole("link", {name: "Wali & Linking", exact: true}).click();
  await expect(page).toHaveURL(/\/guardians/);
  await expect(page.getByRole("heading", {name: "1. Buat akun wali"})).toBeVisible();
  await expect(page.getByRole("heading", {name: "2. Hubungkan wali ke santri"})).toBeVisible();
  await expect(page.getByText(/Request selalu dimulai sebagai PENDING/)).toBeVisible();
  expect(await page.getByLabel("Akun wali").locator("option").count()).toBeGreaterThan(1);
});

test("Tahfidz target UI create then PATCH edit uses strict update DTO", async ({page}) => {
  await login(page);
  await page.getByRole("link", {name: "Tahfidz", exact: true}).click();
  const card = page.locator("section.card").filter({has: page.getByRole("heading", {name: "Target tahfidz"})});
  const studentSelect = card.getByLabel("Santri");
  await waitForRealSelectOptions(studentSelect);
  const options = await studentSelect.locator("option").evaluateAll(nodes => nodes.map(node => ({value: (node as HTMLOptionElement).value, text: node.textContent || ""})).filter(x => x.value));
  expect(options.length).toBeGreaterThan(0);
  await studentSelect.selectOption(options[0].value);
  const selectedStudentName = options[0].text.split("·").pop()?.trim() || options[0].text.trim();
  await card.getByLabel("Target juz").fill("2.5");
  await card.getByLabel("Target tanggal").fill("2026-12-31");
  await expectSuccessfulMutation(page, "POST", "/v1/tahfidz/targets", async () => {
    await card.getByRole("button", {name: "Simpan target"}).click();
  });
  await expect(page.getByText("Target tersimpan.")).toBeVisible();

  const targetRow = card.locator(".compactList > div").filter({hasText: selectedStudentName}).first();
  await targetRow.getByRole("button", {name: "Edit"}).click();
  const editCard = page.locator("section.card").filter({has: page.getByRole("heading", {name: "Edit target tahfidz"})});
  await editCard.getByLabel("Target juz").fill("3");
  await expectSuccessfulMutation(page, "PATCH", "/v1/tahfidz/targets/", async () => {
    await editCard.getByRole("button", {name: "Perbarui target"}).click();
  });
  await expect(page.getByText("Target diperbarui.")).toBeVisible();
});

test("Donation payment-method UI create and deactivate follows create/update DTO split", async ({page}) => {
  await login(page);
  await page.getByRole("link", {name: "Donasi", exact: true}).click();
  const suffix = String(Date.now()).slice(-8);
  const methodCode = `E2E_${suffix}`;
  const displayName = `DEVELOPMENT DATA E2E Method ${suffix}`;
  const formCard = page.locator("section.card").filter({has: page.getByRole("heading", {name: "Rekening / metode pembayaran"})});

  await formCard.getByLabel("Kode metode").fill(methodCode);
  await formCard.getByLabel("Nama tampilan").fill(displayName);
  await formCard.getByLabel("Bank").fill("Development Bank");
  await formCard.getByLabel("Nomor rekening").fill(`9${suffix}`);
  await formCard.getByLabel("Atas nama").fill("Zabisa Development");
  await formCard.getByLabel("Instruksi").fill("Development-only browser E2E method");
  await expectSuccessfulMutation(page, "POST", "/v1/admin/donation/payment-methods", async () => {
    await formCard.getByRole("button", {name: "Simpan metode"}).click();
  });
  await expect(page.getByText("Metode pembayaran tersimpan.")).toBeVisible();

  const row = page.getByRole("row").filter({hasText: methodCode});
  await row.getByRole("button", {name: "Edit"}).click();
  const editCard = page.locator("section.card").filter({has: page.getByRole("heading", {name: "Edit metode pembayaran"})});
  await editCard.getByLabel("Aktif").uncheck();
  await expectSuccessfulMutation(page, "PATCH", "/v1/admin/donation/payment-methods/", async () => {
    await editCard.getByRole("button", {name: "Perbarui metode"}).click();
  });
  await expect(page.getByText("Metode pembayaran diperbarui.")).toBeVisible();
});

test("Notification compose works through Backoffice BFF", async ({page}) => {
  await login(page);
  await page.getByRole("link", {name: "Notifikasi", exact: true}).click();
  const suffix = String(Date.now()).slice(-8);
  const title = `DEVELOPMENT DATA Browser Notification ${suffix}`;
  const card = page.locator("section.card").filter({has: page.getByRole("heading", {name: "Compose"})});
  await expect(card.getByLabel("Audience")).toBeEnabled({timeout: 15_000});
  await card.getByLabel("Audience").selectOption("");
  await card.getByLabel("Tipe").selectOption("ANNOUNCEMENT");
  await card.getByLabel("Judul").fill(title);
  await card.getByLabel("Pesan").fill("Browser E2E notification contract verification");
  await expectSuccessfulMutation(page, "POST", "/v1/admin/notifications", async () => {
    await card.getByRole("button", {name: "Kirim / jadwalkan"}).click();
  });
  await expect(page.getByText("Notifikasi dibuat.")).toBeVisible();
  await expect(page.getByRole("row").filter({hasText: title})).toBeVisible();
});


test("Content Management UI create and update works through strict generic form contract", async ({page}) => {
  await login(page);
  await navigateModule(page, "Konten", /\/content/);
  const suffix = String(Date.now()).slice(-8);
  const slug = `browser-content-${suffix}`;
  const title = `DEVELOPMENT DATA Browser Content ${suffix}`;

  await page.getByLabel("Tipe").selectOption("NEWS");
  await page.getByLabel("Judul").fill(title);
  await page.getByLabel("Slug").fill(slug);
  await page.getByLabel("Ringkasan").fill("Development browser content regression");
  await page.getByLabel("Isi").fill("Browser UI → BFF → content-service contract verification.");
  await expectSuccessfulMutation(page, "POST", "/v1/admin/content", async () => {
    await page.getByRole("button", {name: "Simpan konten"}).click();
  });
  await expect(page.getByText("Data tersimpan.")).toBeVisible();

  const row = page.getByRole("row").filter({hasText: slug});
  await expect(row).toContainText(title);
  await row.getByRole("button", {name: "Edit"}).click();
  await page.getByLabel("Judul").fill(`${title} Updated`);
  await expectSuccessfulMutation(page, "PATCH", "/v1/admin/content/", async () => {
    await page.getByRole("button", {name: "Perbarui konten"}).click();
  });
  await expect(page.getByText("Data diperbarui.")).toBeVisible();
  await expect(page.getByRole("row").filter({hasText: slug})).toContainText("Updated");
});

test("Kajian UI create and update works through strict generic form contract", async ({page}) => {
  await login(page);
  await navigateModule(page, "Kajian & Event", /\/kajian/);
  const suffix = String(Date.now()).slice(-8);
  const slug = `browser-kajian-${suffix}`;
  const title = `DEVELOPMENT DATA Browser Kajian ${suffix}`;

  await page.getByLabel("Judul").fill(title);
  await page.getByLabel("Slug").fill(slug);
  await page.getByLabel("Deskripsi").fill("Development-only browser kajian regression.");
  await page.getByLabel("Pemateri").fill("Browser E2E");
  await page.getByLabel("Mulai").fill("2026-12-31T19:00");
  await page.getByLabel("Lokasi").fill("Development Environment");
  await expectSuccessfulMutation(page, "POST", "/v1/admin/kajian", async () => {
    await page.getByRole("button", {name: "Simpan kajian"}).click();
  });
  await expect(page.getByText("Data tersimpan.")).toBeVisible();

  const row = page.getByRole("row").filter({hasText: slug});
  await expect(row).toContainText(title);
  await row.getByRole("button", {name: "Edit"}).click();
  await page.getByLabel("Pemateri").fill("Browser E2E Updated");
  await expectSuccessfulMutation(page, "PATCH", "/v1/admin/kajian/", async () => {
    await page.getByRole("button", {name: "Perbarui kajian"}).click();
  });
  await expect(page.getByText("Data diperbarui.")).toBeVisible();
});

test("Attendance UI upsert waits for student dependency and persists the note", async ({page}) => {
  await login(page);
  await navigateModule(page, "Kehadiran", /\/attendance/);
  const attendanceCard = page.locator("section.card").filter({
    has: page.getByRole("heading", {name: "Catat kehadiran"}),
  });
  const select = attendanceCard.getByLabel("Santri", {exact: true});
  await waitForRealSelectOptions(select);
  const options = await select.locator("option").evaluateAll(nodes =>
    nodes
      .map(node => ({value: (node as HTMLOptionElement).value, text: node.textContent || ""}))
      .filter(option => option.value),
  );
  await select.selectOption(options[0].value);
  const note = `DEVELOPMENT DATA Browser Attendance ${String(Date.now()).slice(-8)}`;
  await page.getByLabel("Tanggal").fill("2026-12-29");
  await page.getByLabel("Status").selectOption("OTHER");
  await page.getByLabel("Catatan").fill(note);
  await expectSuccessfulMutation(page, "POST", "/v1/admin/attendance", async () => {
    await page.getByRole("button", {name: "Simpan kehadiran"}).click();
  });
  await expect(page.getByText("Kehadiran tersimpan.")).toBeVisible();
  await expect(page.getByRole("row").filter({hasText: note})).toBeVisible();
});

test("Academic subject UI create and deactivate follows write permission contract", async ({page}) => {
  await login(page);
  await navigateModule(page, "Akademik & Report", /\/academics/);
  const suffix = String(Date.now()).slice(-7);
  const code = `E2E${suffix}`;
  const name = `DEVELOPMENT DATA Browser Subject ${suffix}`;
  const card = page.locator("section.card").filter({
    has: page.getByRole("heading", {name: "Master mata pelajaran"}),
  });

  await card.getByLabel("Kode").fill(code);
  await card.getByLabel("Nama").fill(name);
  await card.getByLabel("Kategori").selectOption("ACADEMIC");
  await expectSuccessfulMutation(page, "POST", "/v1/admin/subjects", async () => {
    await card.getByRole("button", {name: "Simpan subject"}).click();
  });
  await expect(page.getByText("Mata pelajaran tersimpan.")).toBeVisible();

  const row = page.getByRole("row").filter({hasText: code});
  await expect(row).toContainText(name);
  await row.getByRole("button", {name: "Edit"}).click();
  const editCard = page.locator("section.card").filter({
    has: page.getByRole("heading", {name: "Edit mata pelajaran"}),
  });
  await editCard.getByLabel("Aktif").uncheck();
  await expectSuccessfulMutation(page, "PATCH", "/v1/admin/subjects/", async () => {
    await editCard.getByRole("button", {name: "Perbarui subject"}).click();
  });
  await expect(page.getByText("Mata pelajaran diperbarui.")).toBeVisible();
  await expect(page.getByRole("row").filter({hasText: code})).toContainText("INACTIVE");
});

test("User & Access UI creates then deactivates a development user", async ({page}) => {
  await login(page);
  await navigateModule(page, "User & Access", /\/access/);
  const suffix = String(Date.now()).slice(-8);
  const email = `phase373.${suffix}@example.invalid`;
  const createCard = page.locator("section.card").filter({
    has: page.getByRole("heading", {name: "Buat akun"}),
  });

  await createCard.getByLabel("Nama").fill(`DEVELOPMENT DATA Browser User ${suffix}`);
  await createCard.getByLabel("Email").fill(email);
  await createCard.getByLabel("Telepon").fill(`0800${suffix}`);
  await createCard.getByLabel("Password awal").fill("BrowserPhase373!");
  await createCard.getByLabel("Role").selectOption("CONTENT_EDITOR");
  await expectSuccessfulMutation(page, "POST", "/v1/admin/users", async () => {
    await createCard.getByRole("button", {name: "Buat akun"}).click();
  });
  await expect(page.getByText("Akun dibuat.")).toBeVisible();

  const row = page.getByRole("row").filter({hasText: email});
  await row.getByRole("button", {name: "Kelola"}).click();
  const accessCard = page.locator("section.card").filter({
    has: page.getByRole("heading", {name: "Ubah hak akses"}),
  });
  await accessCard.getByLabel("Status").selectOption("INACTIVE");
  await expectSuccessfulMutation(page, "PATCH", "/v1/admin/users/", async () => {
    await accessCard.getByRole("button", {name: "Simpan akses"}).click();
  });
  await expect(page.getByText(/Hak akses diperbarui/)).toBeVisible();
  await expect(page.getByRole("row").filter({hasText: email})).toContainText("INACTIVE");
});

test("audit page exposes append-only cross-service provenance", async ({page}) => {
  await login(page);
  await page.getByRole("link", {name: "Audit Log", exact: true}).click();
  await expect(page).toHaveURL(/\/audit/);
  await expect(page.getByRole("columnheader", {name: "Service"})).toBeVisible();
  await expect(page.getByText(/transactional outbox/i)).toBeVisible();
});
