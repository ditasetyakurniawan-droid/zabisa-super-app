# Panduan Developer Zabisa (Bahasa Indonesia)

Dokumen ini adalah titik mulai developer setelah lock delivery DT58 tanggal
6 September 2026. Baca juga `deployment/DT58-SONAR75-DELIVERY-LOCK.md` untuk
bukti build dan batas operasionalnya.

## 1. Kondisi yang sudah dikunci

| Area | Kondisi |
|---|---|
| Source/image | `eee3284a6989857b6d4332f01d453763ccaf71b2` |
| Jenkins readiness | `#18 SUCCESS` |
| Jenkins delivery | `#19 SUCCESS` |
| Sonar New Code coverage | Gate khusus proyek: minimum 75% |
| Harbor | 9 image immutable bertag full source SHA dan digest terverifikasi |
| GitOps | `4fbc8b5db597cbdf73199f8f927eb0ac2cc544c9`, 16 image references / 12 manifests |
| Jenkins parent | DISABLED, tanpa trigger otomatis |
| Kubernetes / migrasi / ArgoCD | BELUM DIJALANKAN |

Lock ini membuktikan source, quality, image, registry, dan publikasi GitOps.
Lock ini bukan pernyataan bahwa aplikasi sudah live di Kubernetes.

## 2. Persiapan satu kali

```bash
cd ~/project-homelab/zabisa-super-app
git switch main
git pull --ff-only origin main
git status --short --branch

node --version
npm --version
go version
docker --version

npm ci --workspaces --include-workspace-root --no-audit --no-fund
```

Gunakan Node 22 atau lebih baru dan versi Go yang tertulis di `go.mod`. Jangan
menjalankan `npm audit fix --force`. Perubahan dependency harus disengaja,
ditinjau, dan menghasilkan `package-lock.json` yang sinkron.

Mulai pekerjaan di branch baru:

```bash
git switch -c feature/nama-perubahan
```

## 3. Dua langkah testing sebelum push

### Langkah 1 — pemeriksaan cepat selama development

```bash
./scripts/developer-check.sh quick
```

Mode ini menjalankan preflight/invariant repository, sinkronisasi lockfile,
lint, typecheck, seluruh unit test Admin dan Mobile, serta pemeriksaan whitespace
Git. Jalankan setiap selesai satu kelompok perubahan.

Padanan manualnya:

```bash
npm run node:lock:verify
./scripts/preflight-offline.sh
npm run lint --workspace=@zabisa/admin-web -- --max-warnings=0
npm run typecheck --workspace=@zabisa/admin-web
npm run test --workspace=@zabisa/admin-web
npm run lint --workspace=@zabisa/mobile -- --max-warnings=0
npm run typecheck --workspace=@zabisa/mobile
npm run test --workspace=@zabisa/mobile
git diff --check
```

### Langkah 2 — gate lengkap sebelum push

```bash
./scripts/developer-check.sh full
```

Mode ini menjalankan `scripts/quality-gate.sh`, sama dengan langkah
`Run repository quality gate` di GitHub: preflight, Go quality/coverage, Python
checks, lint/typecheck/test seluruh workspace, build Backoffice, dan production
dependency audit. Jangan push jika salah satu langkah gagal.

Padanan manualnya:

```bash
./scripts/quality-gate.sh
```

GitHub tetap menjadi bukti remote untuk keseluruhan workflow, termasuk
Backoffice Browser E2E, reachable Go vulnerability review, dan Sonar ketika
diaktifkan. PASS lokal tidak boleh dipakai untuk melewati GitHub.

## 4. Melihat hasil aplikasi di lokal

### Menyalakan backend dan Backoffice

```bash
./scripts/run-local.sh
docker compose ps
curl -fsS http://127.0.0.1:8088/health/ready
```

Buka `http://localhost:3001/login`. Akun demo lokal tersedia di README dan
tidak boleh dipakai di lingkungan bersama/production.

Jika Backoffice memberi 502 dengan pesan `legacy records without checksums`,
jangan mematikan service homelab lain. Ikuti recovery volume lokal yang sudah
didokumentasikan di `LOCAL_DEVELOPMENT.md`.

### Melihat Mobile Android

```bash
npm run mobile:doctor
npm run mobile:device
```

Untuk perangkat fisik, pastikan `adb devices -l` menampilkan device dan gunakan:

```bash
adb reverse tcp:8081 tcp:8082
adb reverse tcp:8088 tcp:8088
```

Metro Zabisa menggunakan host port 8082. Jangan mematikan proses lain yang
memakai port 8081 dan jangan menjalankan `pm clear` pada device acceptance.

## 5. Aturan agar semua pengecekan tetap lolos

1. Jangan menurunkan gate Sonar di bawah 75%. Kondisi yang boleh bernilai 75%
   hanya `new_coverage` pada Quality Gate khusus Zabisa; kondisi lain tidak
   boleh diubah.
2. Jangan mengecualikan API, service, screen, atau business logic dari coverage.
   Exclusion hanya untuk test/mock, generated/type-only, bootstrap, dan runtime
   configuration yang telah tercatat di `sonar-project.properties`.
3. Tambahkan test perilaku untuk setiap branch baru. Jangan mengejar angka
   coverage dengan test tanpa assertion atau dengan menghapus source dari scope.
4. Selesaikan code smell pada sumbernya. Jangan memakai suppression, assertion
   non-null, cast yang tidak perlu, atau exclusion global hanya agar Sonar hijau.
5. Perubahan file yang dilindungi checksum harus disengaja. Setelah test dan
   review perilaku PASS, perbarui baseline checksum terkait dan catat alasannya;
   jangan menghapus verifikasinya.
6. Pertahankan decoder API yang strict, backend RBAC, object authorization,
   audit/outbox, donation idempotency, dan secure token/session storage.
7. Jangan commit secret, token, password, private CA, file coverage, cache,
   `node_modules`, `.next`, atau generated native/build output.
8. Image production wajib bertag full Git SHA dan memakai
   `harbor-dt.co.id/devops-apps/zabisa/<image>`. Dilarang menggunakan `latest`.
9. Jangan menjalankan Jenkins delivery hanya karena source di-push. Delivery
   memerlukan GitHub PASS dan kontrol operator; parent Jenkins harus kembali
   DISABLED.
10. Jangan menjalankan migration, Kubernetes apply, atau ArgoCD sync sebelum
    DT5 backup/restore dan persetujuan phase berikutnya selesai.

## 6. Checklist sebelum commit dan push

```bash
git status --short
git diff --check
git diff --stat
./scripts/developer-check.sh quick
./scripts/developer-check.sh full
```

Pastikan hanya file yang memang terkait perubahan yang masuk commit. Setelah
push, tunggu workflow `Engineering Quality Gate` dan `Backoffice Browser E2E`.
Jika gagal, ambil error pertama dengan:

```bash
gh run view RUN_ID --log-failed
```

Jangan melakukan retry, rollback, force-push, atau melemahkan gate sebelum akar
error diketahui.
