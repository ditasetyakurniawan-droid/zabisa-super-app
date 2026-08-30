#!/usr/bin/env python3
"""Populate Zabisa localhost with deterministic DEVELOPMENT DATA through public/admin APIs.

This script intentionally refuses non-localhost targets. It never writes directly to MySQL.
All records are either discovered by stable development keys or created through the same
HTTP contracts used by the Backoffice/mobile clients.
"""
from __future__ import annotations

import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Any

BASE = os.getenv("ZABISA_API_URL", "http://127.0.0.1:8088").rstrip("/")
PASSWORD = os.getenv("ZABISA_DEMO_PASSWORD", "ChangeMe123!")
PRIMARY_STUDENT_ID = os.getenv("ZABISA_STUDENT_ID", "00000000-0000-4000-8000-000000000101")
ACADEMIC_YEAR = "2026/2027"

parsed = urllib.parse.urlparse(BASE)
if parsed.scheme != "http" or parsed.hostname not in {"127.0.0.1", "localhost", "::1"}:
    raise SystemExit(f"REFUSED: demo seed may only target localhost. BASE={BASE}")


class ApiFailure(RuntimeError):
    pass


@dataclass
class Client:
    base: str

    def call(
        self,
        path: str,
        *,
        method: str = "GET",
        token: str | None = None,
        data: Any | None = None,
        headers: dict[str, str] | None = None,
        expected: tuple[int, ...] = (200, 201, 204),
    ) -> Any:
        body = None if data is None else json.dumps(data).encode()
        req_headers = {"Accept": "application/json"}
        if data is not None:
            req_headers["Content-Type"] = "application/json"
        if token:
            req_headers["Authorization"] = f"Bearer {token}"
        if headers:
            req_headers.update(headers)
        req = urllib.request.Request(self.base + path, data=body, method=method, headers=req_headers)
        try:
            with urllib.request.urlopen(req, timeout=15) as response:
                raw = response.read()
                status = response.status
        except urllib.error.HTTPError as exc:
            raw = exc.read()
            status = exc.code
        except Exception as exc:  # noqa: BLE001 - diagnostic CLI
            raise ApiFailure(f"{method} {path}: {exc}") from exc

        if status not in expected:
            detail = raw.decode(errors="replace")[:1200]
            raise ApiFailure(f"{method} {path}: HTTP {status}: {detail}")
        if not raw:
            return None
        payload = json.loads(raw)
        if isinstance(payload, dict) and "error" in payload and payload.get("error"):
            raise ApiFailure(f"{method} {path}: API error: {payload['error']}")
        return payload.get("data") if isinstance(payload, dict) and "data" in payload else payload

    def login(self, email: str, device: str) -> tuple[str, dict[str, Any]]:
        data = self.call(
            "/api/v1/auth/login",
            method="POST",
            data={"email": email, "password": PASSWORD, "device_id": device},
        )
        return data["access_token"], data.get("user") or {}


api = Client(BASE)


def log(message: str) -> None:
    print(message, flush=True)


def find(items: list[dict[str, Any]], **criteria: Any) -> dict[str, Any] | None:
    for item in items:
        if all(str(item.get(key, "")) == str(value) for key, value in criteria.items()):
            return item
    return None


def refresh_users(admin_token: str) -> list[dict[str, Any]]:
    return api.call("/api/v1/admin/users", token=admin_token) or []


def ensure_user(admin_token: str, users: list[dict[str, Any]], email: str, name: str, role: str) -> dict[str, Any]:
    existing = find(users, email=email)
    if existing:
        log(f"EXISTS user: {email} ({existing.get('role')})")
        return existing
    created = api.call(
        "/api/v1/admin/users",
        method="POST",
        token=admin_token,
        data={"email": email, "phone": "", "password": PASSWORD, "display_name": name, "role": role},
    )
    log(f"CREATED user: {email} ({role})")
    users[:] = refresh_users(admin_token)
    return find(users, email=email) or {"id": created["id"], "email": email, "role": role}


def ensure_content(admin_token: str, content_type: str, title: str, slug: str, summary: str, body: str) -> dict[str, Any]:
    items = api.call(f"/api/v1/admin/content?type={urllib.parse.quote(content_type)}", token=admin_token) or []
    existing = find(items, slug=slug)
    if existing:
        log(f"EXISTS content: {content_type} / {title}")
        return existing
    created = api.call(
        "/api/v1/admin/content",
        method="POST",
        token=admin_token,
        data={
            "type": content_type,
            "title": title,
            "slug": slug,
            "summary": summary,
            "body": body,
            "image_url": "",
            "published": True,
        },
    )
    log(f"CREATED content: {content_type} / {title}")
    return {"id": created["id"], "type": content_type, "title": title, "slug": slug}


def ensure_kajian(admin_token: str, spec: dict[str, Any]) -> dict[str, Any]:
    items = api.call("/api/v1/admin/kajian", token=admin_token) or []
    existing = find(items, slug=spec["slug"])
    if existing:
        api.call(f"/api/v1/admin/kajian/{existing['id']}", method="PATCH", token=admin_token, data=spec)
        log(f"REFRESHED kajian: {spec['title']}")
        return {**existing, **spec}
    created = api.call("/api/v1/admin/kajian", method="POST", token=admin_token, data=spec)
    log(f"CREATED kajian: {spec['title']}")
    return {"id": created["id"], **spec}


def ensure_payment_method(admin_token: str, code: str) -> None:
    methods = api.call("/api/v1/donation/payment-methods") or []
    if find(methods, method_code=code):
        log(f"EXISTS payment method: {code}")
        return
    api.call(
        "/api/v1/admin/donation/payment-methods",
        method="POST",
        token=admin_token,
        data={
            "method_code": code,
            "display_name": "Transfer Bank Demo",
            "bank_name": "Bank Syariah Demo",
            "account_number": "000123456789",
            "account_holder": "Yayasan Zabisa (DEVELOPMENT)",
            "instructions": "DEVELOPMENT DATA: gunakan hanya untuk simulasi alur donasi lokal.",
        },
    )
    log(f"CREATED payment method: {code}")


def ensure_campaign(admin_token: str, spec: dict[str, Any]) -> dict[str, Any]:
    items = api.call("/api/v1/admin/donation/campaigns", token=admin_token) or []
    existing = find(items, slug=spec["slug"])
    if existing:
        log(f"EXISTS campaign: {spec['name']}")
        campaign = existing
    else:
        created = api.call("/api/v1/admin/donation/campaigns", method="POST", token=admin_token, data=spec)
        campaign = {"id": created["id"], **spec, "collected_amount": 0, "status": "ACTIVE"}
        log(f"CREATED campaign: {spec['name']}")
    return campaign


def ensure_campaign_update(admin_token: str, campaign_id: str, title: str, body: str) -> None:
    items = api.call(f"/api/v1/donation/campaigns/{campaign_id}/updates") or []
    if any(item.get("title") == title for item in items):
        log(f"EXISTS campaign update: {title}")
        return
    api.call(
        f"/api/v1/admin/donation/campaigns/{campaign_id}/updates",
        method="POST",
        token=admin_token,
        data={"title": title, "body": body},
    )
    log(f"CREATED campaign update: {title}")


def ensure_student(admin_token: str, student_no: str, full_name: str, class_name: str, program_name: str) -> dict[str, Any]:
    items = api.call("/api/v1/admin/students", token=admin_token) or []
    existing = find(items, student_no=student_no)
    if existing:
        log(f"EXISTS student: {full_name}")
        return existing
    created = api.call(
        "/api/v1/admin/students",
        method="POST",
        token=admin_token,
        data={
            "student_no": student_no,
            "full_name": full_name,
            "class_name": class_name,
            "program_name": program_name,
            "academic_year": ACADEMIC_YEAR,
        },
    )
    log(f"CREATED student: {full_name}")
    return {"id": created["id"], "student_no": student_no, "full_name": full_name, "class_name": class_name, "program_name": program_name, "academic_year": ACADEMIC_YEAR, "status": "ACTIVE"}


def ensure_guardian_link(admin_token: str, guardian_user_id: str, student: dict[str, Any]) -> None:
    links = api.call("/api/v1/admin/guardian-links", token=admin_token) or []
    existing = next((x for x in links if x.get("guardian_user_id") == guardian_user_id and x.get("student_id") == student["id"]), None)
    if existing and existing.get("status") == "APPROVED":
        log(f"EXISTS guardian link: {student['full_name']}")
        return
    if existing:
        link_id = existing["id"]
    else:
        created = api.call(
            "/api/v1/admin/guardian-links",
            method="POST",
            token=admin_token,
            data={"guardian_user_id": guardian_user_id, "student_id": student["id"], "relationship": "FATHER"},
        )
        link_id = created["id"]
    api.call(f"/api/v1/admin/guardian-links/{link_id}/approve", method="PATCH", token=admin_token)
    log(f"APPROVED guardian link: {student['full_name']}")


def ensure_tahfidz_entry(ustadz_token: str, student_id: str, marker: str, spec: dict[str, Any]) -> str:
    items = api.call(f"/api/v1/tahfidz/entries?student_id={student_id}", token=ustadz_token) or []
    existing = next((x for x in items if x.get("teacher_note") == marker), None)
    if existing:
        log(f"EXISTS tahfidz: {spec['surah']} / {marker.split(':')[-1].strip()}")
        return existing["id"]
    payload = {"student_id": student_id, "teacher_note": marker, **spec}
    created = api.call("/api/v1/tahfidz/entries", method="POST", token=ustadz_token, data=payload)
    log(f"CREATED tahfidz: {spec['surah']} {spec['ayah_start']}-{spec['ayah_end']}")
    return created["id"]


def ensure_tahfidz_target(ustadz_token: str, student_id: str, target_juz: float, target_date: str) -> None:
    items = api.call(f"/api/v1/tahfidz/targets?student_id={student_id}", token=ustadz_token) or []
    if any(float(x.get("target_juz") or 0) == float(target_juz) and str(x.get("target_date") or "")[:10] == target_date for x in items):
        log(f"EXISTS tahfidz target: student={student_id[-4:]} target={target_juz} juz")
        return
    api.call("/api/v1/tahfidz/targets", method="POST", token=ustadz_token, data={"student_id": student_id, "target_juz": target_juz, "target_date": target_date})
    log(f"CREATED tahfidz target: student={student_id[-4:]} target={target_juz} juz")


def ensure_subject(teacher_token: str, code: str, name: str, category: str) -> dict[str, Any]:
    items = api.call("/api/v1/subjects", token=teacher_token) or []
    existing = find(items, code=code)
    if existing:
        return existing
    created = api.call("/api/v1/admin/subjects", method="POST", token=teacher_token, data={"code": code, "name": name, "category": category})
    log(f"CREATED subject: {name}")
    return {"id": created["id"], "code": code, "name": name, "category": category}


def ensure_grade(teacher_token: str, student_id: str, subject: dict[str, Any], assessment: str, score: float, grade: str, note: str) -> str:
    items = api.call(f"/api/v1/admin/grades?student_id={student_id}", token=teacher_token) or []
    existing = next((x for x in items if x.get("subject_code") == subject["code"] and x.get("assessment_type") == assessment and x.get("published")), None)
    if existing:
        log(f"EXISTS grade: {subject['name']} / {assessment}")
        return existing["id"]
    created = api.call(
        "/api/v1/grades",
        method="POST",
        token=teacher_token,
        data={
            "student_id": student_id,
            "subject_id": subject["id"],
            "academic_year": ACADEMIC_YEAR,
            "semester": "1",
            "assessment_type": assessment,
            "score": score,
            "grade": grade,
            "teacher_note": note,
            "published": True,
        },
    )
    log(f"CREATED grade: {subject['name']} = {score:g}")
    return created["id"]


def upsert_attendance(admin_token: str, student_id: str, date: str, status: str, note: str) -> None:
    api.call(
        "/api/v1/admin/attendance",
        method="POST",
        token=admin_token,
        data={"student_id": student_id, "date": date, "status": status, "note": note},
    )


def ensure_report(admin_token: str, student_id: str, report_type: str, semester: str = "1") -> str:
    items = api.call(f"/api/v1/admin/reports?student_id={student_id}", token=admin_token) or []
    existing = next((x for x in items if x.get("academic_year") == ACADEMIC_YEAR and str(x.get("semester")) == semester and x.get("report_type") == report_type), None)
    if existing:
        report_id = existing["id"]
        status = existing.get("status")
    else:
        created = api.call(
            "/api/v1/admin/reports",
            method="POST",
            token=admin_token,
            data={"student_id": student_id, "academic_year": ACADEMIC_YEAR, "semester": semester, "report_type": report_type},
        )
        report_id = created["id"]
        status = "DRAFT"
        log(f"CREATED report: {report_type}")
    if status != "PUBLISHED":
        api.call(f"/api/v1/admin/reports/{report_id}/publish", method="PATCH", token=admin_token)
        log(f"PUBLISHED report: {report_type}")
    return report_id


def ensure_donation(guardian_token: str, admin_token: str, campaign: dict[str, Any], suffix: str, amount: int, paid: bool, payment_method: str) -> str:
    key = f"zabisa-development-demo-{suffix}-v1"
    created = api.call(
        "/api/v1/donations",
        method="POST",
        token=guardian_token,
        headers={"Idempotency-Key": key},
        data={
            "campaign_id": campaign["id"],
            "donor_name": "Wali Santri Demo",
            "donor_email": "guardian@zabisa.local",
            "anonymous": False,
            "message": "DEVELOPMENT DATA: semoga bermanfaat untuk program pesantren.",
            "amount": amount,
            "payment_method": payment_method,
        },
    )
    donation_id = created["id"]
    state = api.call(f"/api/v1/donations/{donation_id}")
    if paid and state.get("status") != "PAID":
        api.call(f"/api/v1/admin/donations/{donation_id}/verify", method="PATCH", token=admin_token)
        log(f"VERIFIED donation: {campaign['name']} / Rp {amount:,}".replace(",", "."))
    else:
        log(f"EXISTS donation: {campaign['name']} / {state.get('status')}")
    return donation_id


def ensure_notification(admin_token: str, existing: list[dict[str, Any]], *, user_id: str | None, typ: str, title: str, message: str, deep_link: str = "") -> None:
    if any(x.get("title") == title and (x.get("user_id") or "") == (user_id or "") for x in existing):
        log(f"EXISTS notification: {title}")
        return
    api.call(
        "/api/v1/admin/notifications",
        method="POST",
        token=admin_token,
        data={"user_id": user_id or "", "type": typ, "title": title, "message": message, "deep_link": deep_link, "scheduled_at": ""},
    )
    log(f"CREATED notification: {title}")


def ensure_scheduled_notification(admin_token: str, guardian_id: str, student_id: str) -> None:
    title = "Pengingat evaluasi bulanan (Demo)"
    scheduled = api.call("/api/v1/admin/notifications/scheduled", token=admin_token) or []
    if any(x.get("title") == title for x in scheduled):
        log(f"EXISTS scheduled notification: {title}")
        return
    when = (datetime.now(timezone.utc) + timedelta(hours=18)).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    api.call(
        "/api/v1/admin/notifications",
        method="POST",
        token=admin_token,
        data={
            "user_id": guardian_id,
            "type": "REMINDER",
            "title": title,
            "message": "DEVELOPMENT DATA: jadwal simulasi notifikasi terjadwal.",
            "deep_link": f"zabisa://guardian/students/{student_id}/academic/demo-reminder",
            "scheduled_at": when,
        },
    )
    log(f"CREATED scheduled notification: {title}")


def main() -> None:
    api.call("/health/live")
    log("=== Zabisa Phase 3.3: FULL DEVELOPMENT DATA ===")
    log(f"API: {BASE}")
    log("All records below are fictitious DEVELOPMENT DATA.\n")

    admin_token, _ = api.login("admin@zabisa.local", "phase33-admin")
    guardian_token, guardian_session_user = api.login("guardian@zabisa.local", "phase33-guardian")
    ustadz_token, _ = api.login("ustadz@zabisa.local", "phase33-ustadz")
    teacher_token, _ = api.login("teacher@zabisa.local", "phase33-teacher")

    users = refresh_users(admin_token)
    guardian_user = find(users, email="guardian@zabisa.local")
    if not guardian_user:
        # Login response currently has id but not email; user list is canonical for admin seeding.
        guardian_id = guardian_session_user.get("id")
        guardian_user = {"id": guardian_id, "email": "guardian@zabisa.local"}
    ensure_user(admin_token, users, "operator@zabisa.local", "Operator Demo", "OPERATOR")
    ensure_user(admin_token, users, "content@zabisa.local", "Editor Konten Demo", "CONTENT_EDITOR")
    ensure_user(admin_token, users, "finance@zabisa.local", "Finance Demo", "FINANCE")

    log("\n--- PUBLIC CONTENT ---")
    content_specs = [
        ("PROFILE", "Tentang Pesantren Zabisa (Demo)", "dev-profile-zabisa", "Pesantren yang memadukan pendidikan, tahfidz, adab, dan kemandirian.", "DEVELOPMENT DATA. Zabisa hadir sebagai lingkungan belajar yang menumbuhkan akhlak, ilmu, kemandirian, dan kepedulian sosial santri."),
        ("PROFILE", "Visi & Misi Zabisa (Demo)", "dev-profile-visi-misi", "Arah pendidikan dan pembinaan santri Zabisa.", "DEVELOPMENT DATA. Visi: membentuk generasi berilmu, beradab, mandiri, dan bermanfaat. Misi: pembinaan Al-Qur'an, akademik, karakter, kepemimpinan, dan kepedulian sosial."),
        ("PROGRAM", "Program Tahfidz Intensif (Demo)", "dev-program-tahfidz", "Pendampingan hafalan dengan target dan evaluasi terukur.", "DEVELOPMENT DATA. Program meliputi setoran, murajaah, tasmi, evaluasi tajwid, dan pendampingan target hafalan."),
        ("PROGRAM", "Beasiswa Santri Berprestasi (Demo)", "dev-program-beasiswa", "Dukungan pendidikan bagi santri berprestasi dan membutuhkan.", "DEVELOPMENT DATA. Program beasiswa membantu biaya pendidikan, perlengkapan belajar, dan pembinaan prestasi."),
        ("PROGRAM", "Kelas Kemandirian Santri (Demo)", "dev-program-kemandirian", "Pembelajaran kewirausahaan dan keterampilan hidup.", "DEVELOPMENT DATA. Santri belajar pengelolaan proyek sederhana, komunikasi, kerja tim, dan tanggung jawab."),
        ("NEWS", "Santri Zabisa Raih Prestasi Tahfidz (Demo)", "dev-news-prestasi-tahfidz", "Simulasi berita prestasi santri dalam evaluasi tahfidz.", "DEVELOPMENT DATA. Sejumlah santri menunjukkan perkembangan hafalan dan tajwid yang baik pada evaluasi bulanan."),
        ("NEWS", "Bakti Sosial Bersama Warga (Demo)", "dev-news-bakti-sosial", "Kegiatan pengabdian sosial santri di lingkungan sekitar.", "DEVELOPMENT DATA. Santri dan pembimbing melaksanakan kegiatan berbagi paket kebutuhan pokok dan kerja bakti bersama masyarakat."),
        ("NEWS", "Pembukaan Tahun Ajaran 2026/2027 (Demo)", "dev-news-tahun-ajaran", "Informasi kegiatan awal tahun ajaran.", "DEVELOPMENT DATA. Kegiatan pembukaan diisi orientasi santri, pertemuan wali, pengenalan program akademik, dan target tahfidz."),
        ("GALLERY", "Galeri Setoran Tahfidz (Demo)", "dev-gallery-tahfidz", "Dokumentasi simulasi kegiatan halaqah dan setoran.", "DEVELOPMENT DATA. Galeri metadata untuk mendemonstrasikan modul dokumentasi. Media upload asli akan mengikuti media-service/S3 sesuai roadmap."),
        ("GALLERY", "Galeri Kegiatan Santri (Demo)", "dev-gallery-kegiatan", "Dokumentasi simulasi kegiatan belajar dan kebersamaan.", "DEVELOPMENT DATA. Metadata galeri ini bersifat fiktif dan tidak menggunakan foto santri nyata."),
        ("GALLERY", "Galeri Wisuda Tahfidz (Demo)", "dev-gallery-wisuda", "Dokumentasi simulasi apresiasi capaian hafalan.", "DEVELOPMENT DATA. Tidak ada identitas atau foto anak nyata pada seed ini."),
        ("ARTICLE", "Menjaga Murajaah Tetap Konsisten (Demo)", "dev-article-murajaah", "Tips sederhana membangun kebiasaan murajaah.", "DEVELOPMENT DATA. Konsistensi dapat dibantu dengan target kecil, jadwal tetap, pencatatan progres, dan evaluasi berkala."),
        ("ANNOUNCEMENT", "Agenda Pertemuan Wali Santri (Demo)", "dev-announcement-wali", "Simulasi pengumuman agenda wali santri.", "DEVELOPMENT DATA. Agenda demo dijadwalkan untuk memperlihatkan modul pengumuman di Backoffice."),
        ("BANNER", "Selamat Datang di Zabisa (Demo)", "dev-banner-welcome", "Banner pengembangan untuk data CMS.", "DEVELOPMENT DATA. Banner disiapkan sebagai metadata sampai media-service diaktifkan."),
    ]
    for spec in content_specs:
        ensure_content(admin_token, *spec)

    now = datetime.now(timezone.utc)
    kajian_specs = [
        {
            "title": "Kajian Ahad Pagi: Adab Penuntut Ilmu (Demo)", "slug": "dev-kajian-adab-ilmu", "description": "DEVELOPMENT DATA. Kajian simulasi tentang adab belajar dan keberkahan ilmu.", "speaker": "Ustadz Ahmad Demo", "start_at": (now + timedelta(days=2, hours=2)).replace(microsecond=0).isoformat(), "end_at": (now + timedelta(days=2, hours=4)).replace(microsecond=0).isoformat(), "location": "Masjid Utama Zabisa - Demo", "map_url": "https://maps.google.com/?q=Temanggung", "live_url": "", "poster_url": "", "published": True,
        },
        {
            "title": "Kajian Keluarga: Mendidik dengan Keteladanan (Demo)", "slug": "dev-kajian-keluarga", "description": "DEVELOPMENT DATA. Kajian simulasi untuk wali santri dan masyarakat.", "speaker": "Ustadzah Fatimah Demo", "start_at": (now + timedelta(days=5, hours=1)).replace(microsecond=0).isoformat(), "end_at": (now + timedelta(days=5, hours=3)).replace(microsecond=0).isoformat(), "location": "Aula Zabisa - Demo", "map_url": "https://maps.google.com/?q=Temanggung", "live_url": "", "poster_url": "", "published": True,
        },
        {
            "title": "Dauroh Tahsin Al-Qur'an (Demo)", "slug": "dev-kajian-tahsin", "description": "DEVELOPMENT DATA. Simulasi dauroh tahsin dan penguatan makharijul huruf.", "speaker": "Ustadz Yusuf Demo", "start_at": (now + timedelta(days=8)).replace(microsecond=0).isoformat(), "end_at": (now + timedelta(days=8, hours=3)).replace(microsecond=0).isoformat(), "location": "Ruang Tahfidz Zabisa - Demo", "map_url": "", "live_url": "", "poster_url": "", "published": True,
        },
    ]
    kajian = [ensure_kajian(admin_token, item) for item in kajian_specs]

    log("\n--- DONATION ---")
    ensure_payment_method(admin_token, "DEV_BANK_TRANSFER")
    deadline = (now + timedelta(days=90)).replace(microsecond=0).isoformat()
    campaign_specs = [
        {"name": "Beasiswa Santri Yatim (Demo)", "slug": "dev-donasi-beasiswa-yatim", "description": "DEVELOPMENT DATA. Simulasi campaign biaya pendidikan dan perlengkapan santri yatim.", "category": "Pendidikan", "target_amount": 50_000_000, "cover_url": "", "deadline": deadline},
        {"name": "Wakaf Renovasi Asrama (Demo)", "slug": "dev-donasi-asrama", "description": "DEVELOPMENT DATA. Simulasi campaign perbaikan fasilitas asrama santri.", "category": "Wakaf", "target_amount": 150_000_000, "cover_url": "", "deadline": deadline},
        {"name": "Paket Al-Qur'an Santri (Demo)", "slug": "dev-donasi-quran", "description": "DEVELOPMENT DATA. Simulasi pengadaan mushaf dan perlengkapan tahfidz.", "category": "Al-Qur'an", "target_amount": 25_000_000, "cover_url": "", "deadline": deadline},
    ]
    campaigns = [ensure_campaign(admin_token, item) for item in campaign_specs]
    ensure_campaign_update(admin_token, campaigns[0]["id"], "Distribusi tahap pertama (Demo)", "DEVELOPMENT DATA. Simulasi update bahwa bantuan tahap pertama telah dialokasikan untuk kebutuhan pendidikan.")
    ensure_campaign_update(admin_token, campaigns[1]["id"], "Persiapan renovasi (Demo)", "DEVELOPMENT DATA. Simulasi progres pengukuran dan perencanaan pekerjaan asrama.")
    ensure_campaign_update(admin_token, campaigns[2]["id"], "Pengadaan mushaf dimulai (Demo)", "DEVELOPMENT DATA. Simulasi update pengadaan mushaf tahfidz.")
    ensure_donation(guardian_token, admin_token, campaigns[0], "beasiswa-paid", 750_000, True, "DEV_BANK_TRANSFER")
    ensure_donation(guardian_token, admin_token, campaigns[1], "asrama-pending", 250_000, False, "DEV_BANK_TRANSFER")
    ensure_donation(guardian_token, admin_token, campaigns[2], "quran-paid", 500_000, True, "DEV_BANK_TRANSFER")

    log("\n--- STUDENT / GUARDIAN ---")
    primary = {"id": PRIMARY_STUDENT_ID, "student_no": "ZB-DEMO-001", "full_name": "Ahmad Fulan Demo", "class_name": "Kelas A", "program_name": "Tahfidz", "academic_year": ACADEMIC_YEAR}
    second = ensure_student(admin_token, "ZB-DEMO-002", "Fatimah Fulanah Demo", "Kelas B", "Tahfidz & Akademik")
    guardian_id = str(guardian_user["id"])
    ensure_guardian_link(admin_token, guardian_id, primary)
    ensure_guardian_link(admin_token, guardian_id, second)

    today = datetime.now().date()
    tahfidz_specs = {
        primary["id"]: [
            ("DEVELOPMENT DATA: Al-Baqarah setoran demo", {"activity_date": str(today), "surah": "Al-Baqarah", "ayah_start": 1, "ayah_end": 5, "juz": 1, "page": 2, "activity_type": "NEW_MEMORIZATION", "score": 90, "fluency": "Baik", "tajwid": "Baik", "makhraj": "Baik",}),
            ("DEVELOPMENT DATA: Al-Fatihah murajaah demo", {"activity_date": str(today - timedelta(days=1)), "surah": "Al-Fatihah", "ayah_start": 1, "ayah_end": 7, "juz": 1, "page": 1, "activity_type": "MURAJAAH", "score": 92, "fluency": "Sangat baik", "tajwid": "Baik", "makhraj": "Baik",}),
            ("DEVELOPMENT DATA: An-Nas tasmi demo", {"activity_date": str(today - timedelta(days=3)), "surah": "An-Nas", "ayah_start": 1, "ayah_end": 6, "juz": 30, "page": 604, "activity_type": "TASMI", "score": 95, "fluency": "Sangat baik", "tajwid": "Sangat baik", "makhraj": "Baik",}),
        ],
        second["id"]: [
            ("DEVELOPMENT DATA: Al-Ikhlas setoran demo", {"activity_date": str(today), "surah": "Al-Ikhlas", "ayah_start": 1, "ayah_end": 4, "juz": 30, "page": 604, "activity_type": "NEW_MEMORIZATION", "score": 91, "fluency": "Baik", "tajwid": "Baik", "makhraj": "Baik",}),
            ("DEVELOPMENT DATA: Al-Falaq murajaah demo", {"activity_date": str(today - timedelta(days=2)), "surah": "Al-Falaq", "ayah_start": 1, "ayah_end": 5, "juz": 30, "page": 604, "activity_type": "MURAJAAH", "score": 89, "fluency": "Baik", "tajwid": "Baik", "makhraj": "Cukup",}),
        ],
    }
    tahfidz_entry_ids: dict[str, list[str]] = {}
    for student_id, entries in tahfidz_specs.items():
        tahfidz_entry_ids[student_id] = [ensure_tahfidz_entry(ustadz_token, student_id, marker, spec) for marker, spec in entries]
        ensure_tahfidz_target(ustadz_token, student_id, 2.0 if student_id == primary["id"] else 1.0, str(today + timedelta(days=120)))

    log("\n--- ACADEMIC / ATTENDANCE / REPORT ---")
    subjects = [
        ensure_subject(teacher_token, "DEV-PAI-01", "Pendidikan Agama Islam", "RELIGIOUS"),
        ensure_subject(teacher_token, "DEV-MTK-01", "Matematika", "ACADEMIC"),
        ensure_subject(teacher_token, "DEV-BIN-01", "Bahasa Indonesia", "ACADEMIC"),
        ensure_subject(teacher_token, "DEV-IPA-01", "Ilmu Pengetahuan Alam", "ACADEMIC"),
        ensure_subject(teacher_token, "DEV-AKH-01", "Akhlak & Adab", "RELIGIOUS"),
    ]
    score_sets = {
        primary["id"]: [88, 84, 90, 86, 94],
        second["id"]: [92, 87, 89, 91, 95],
    }
    grade_ids: dict[str, list[str]] = {}
    for student_id, scores in score_sets.items():
        grade_ids[student_id] = []
        for subject, score in zip(subjects, scores):
            letter = "A" if score >= 90 else "B+" if score >= 85 else "B"
            grade_ids[student_id].append(ensure_grade(teacher_token, student_id, subject, "DEVELOPMENT_DEMO", score, letter, "DEVELOPMENT DATA: hasil simulasi untuk validasi tampilan wali santri."))

        attendance_rows = [
            (today - timedelta(days=6), "PRESENT", "Hadir tepat waktu"),
            (today - timedelta(days=5), "PRESENT", "Mengikuti kegiatan belajar"),
            (today - timedelta(days=4), "PERMITTED", "Izin kegiatan keluarga"),
            (today - timedelta(days=3), "PRESENT", "Hadir"),
            (today - timedelta(days=2), "SICK", "Izin sakit"),
            (today - timedelta(days=1), "PRESENT", "Hadir"),
            (today, "PRESENT", "Hadir dan mengikuti halaqah"),
        ]
        for d, status, note in attendance_rows:
            upsert_attendance(admin_token, student_id, str(d), status, f"DEVELOPMENT DATA: {note}")
        log(f"UPSERT attendance: {student_id[-4:]} / {len(attendance_rows)} days")
        ensure_report(admin_token, student_id, "PROGRESS_SEMESTER", "1")
        ensure_report(admin_token, student_id, "REPORT_CARD", "1")

    log("\n--- NOTIFICATIONS ---")
    time.sleep(2.0)  # allow transactional-outbox workers to dispatch newly-created events
    existing_notifications = api.call("/api/v1/admin/notifications", token=admin_token) or []
    ensure_notification(admin_token, existing_notifications, user_id=guardian_id, typ="GENERAL", title="Selamat datang di Portal Wali (Demo)", message="DEVELOPMENT DATA: semua data pada akun ini bersifat fiktif untuk pengembangan.", deep_link="")
    ensure_notification(admin_token, existing_notifications, user_id=guardian_id, typ="ANNOUNCEMENT", title="Pertemuan wali santri (Demo)", message="DEVELOPMENT DATA: simulasi pengingat agenda pertemuan wali santri.", deep_link=f"zabisa://guardian/students/{primary["id"]}/academic/demo-announcement")
    ensure_notification(admin_token, existing_notifications, user_id=None, typ="GENERAL", title="Informasi umum Zabisa (Demo)", message="DEVELOPMENT DATA: simulasi notifikasi umum yang dapat dibaca akun terautentikasi.", deep_link=f"zabisa://kajian/{kajian[0]['id']}")
    ensure_scheduled_notification(admin_token, guardian_id, primary["id"])

    log("\n--- FINAL SUMMARY ---")
    students = api.call("/api/v1/guardian/students", token=guardian_token) or []
    history = api.call("/api/v1/donations/history", token=guardian_token) or []
    notifications = api.call("/api/v1/notifications", token=guardian_token) or []
    public_counts = {
        "kajian": len(api.call("/api/v1/kajian") or []),
        "news": len(api.call("/api/v1/content?type=NEWS") or []),
        "programs": len(api.call("/api/v1/content?type=PROGRAM") or []),
        "profiles": len(api.call("/api/v1/content?type=PROFILE") or []),
        "gallery": len(api.call("/api/v1/content?type=GALLERY") or []),
        "campaigns": len(api.call("/api/v1/donation/campaigns") or []),
        "payment_methods": len(api.call("/api/v1/donation/payment-methods") or []),
    }
    print(json.dumps({
        "public": public_counts,
        "guardian": {"students": len(students), "donation_history": len(history), "notifications": len(notifications)},
        "credentials": {
            "guardian": "guardian@zabisa.local",
            "admin": "admin@zabisa.local",
            "ustadz": "ustadz@zabisa.local",
            "teacher": "teacher@zabisa.local",
            "operator": "operator@zabisa.local",
            "content_editor": "content@zabisa.local",
            "finance": "finance@zabisa.local",
            "password": PASSWORD,
        },
        "warning": "DEVELOPMENT DATA ONLY - never use these credentials or records in production",
    }, indent=2, ensure_ascii=False))
    log("\n=== FULL DEVELOPMENT DATA: READY ===")


if __name__ == "__main__":
    try:
        main()
    except ApiFailure as exc:
        print(f"SEED FAILED: {exc}", file=sys.stderr)
        raise SystemExit(1)
