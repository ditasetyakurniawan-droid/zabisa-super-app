# Announcement Developer — Lock DT58 Zabisa

DT58 Zabisa telah dikunci pada application/image revision
`eee3284a6989857b6d4332f01d453763ccaf71b2` dan GitOps revision
`4fbc8b5db597cbdf73199f8f927eb0ac2cc544c9`. Jenkins readiness `#18` dan
delivery `#19` SUCCESS, 9 image Harbor beserta digest terverifikasi, 16 image
references telah dipublikasikan, dan parent Jenkins kembali DISABLED.

Perlu diperhatikan oleh seluruh developer:

- Sonar New Code coverage minimum 75% hanya pada Quality Gate khusus Zabisa;
  kondisi quality/security lainnya tetap berlaku.
- Jangan menambah coverage exclusion untuk business API, service, screen, atau
  flow penting. Tambahkan behavioural test untuk code baru.
- Jangan mengatasi code smell dengan suppression, cast/non-null assertion yang
  tidak perlu, atau memindahkan source penting keluar dari scope Sonar.
- Jalankan `./scripts/developer-check.sh quick` selama development dan
  `./scripts/developer-check.sh full` sebelum push.
- Gunakan feature branch, review `git diff`, dan tunggu GitHub Engineering
  Quality Gate serta Browser E2E PASS.
- Image wajib immutable dengan full Git SHA; `latest` dilarang.
- Push source tidak memberi izin menjalankan Jenkins delivery.
- Kubernetes, MySQL migration, dan ArgoCD sync BELUM dijalankan. Ketiganya
  menunggu DT5 backup/restore proof dan approval terpisah.

Panduan praktik lengkap: `docs/DEVELOPER_GUIDE_ID.md`.
