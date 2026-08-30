const DATE_ONLY = /^\d{4}-\d{2}-\d{2}$/;

export function formatCurrencyID(value: number | string | null | undefined) {
  const numeric = Number(value ?? 0);
  return `Rp ${Number.isFinite(numeric) ? numeric.toLocaleString('id-ID') : '0'}`;
}

export function formatDateID(value?: string | null) {
  if (!value) return '-';
  const date = DATE_ONLY.test(value) ? new Date(`${value}T00:00:00`) : new Date(value);
  if (Number.isNaN(date.getTime())) return '-';
  return new Intl.DateTimeFormat('id-ID', {
    day: 'numeric', month: 'long', year: 'numeric',
  }).format(date);
}

export function formatDateTimeID(value?: string | null) {
  if (!value) return '-';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '-';
  const day = new Intl.DateTimeFormat('id-ID', {
    day: 'numeric', month: 'long', year: 'numeric',
  }).format(date);
  const time = new Intl.DateTimeFormat('id-ID', {
    hour: '2-digit', minute: '2-digit', hour12: false,
  }).format(date).replace(':', '.');
  return `${day} • ${time}`;
}

export function formatActivityType(value?: string | null) {
  const labels: Record<string, string> = {
    SETORAN: 'Setoran', MURAJAAH: 'Murajaah', TASMI: 'Tasmi', EVALUATION: 'Evaluasi',
  };
  const normalized = value?.trim().toUpperCase();
  return normalized ? labels[normalized] ?? value ?? '-' : '-';
}

export function formatAttendanceStatus(value?: string | null) {
  const labels: Record<string, string> = {
    PRESENT: 'Hadir', ABSENT: 'Tidak hadir', SICK: 'Sakit',
    EXCUSED: 'Izin', PERMISSION: 'Izin', PERMITTED: 'Izin', OTHER: 'Lainnya',
  };
  const normalized = value?.trim().toUpperCase();
  return normalized ? labels[normalized] ?? value ?? '-' : '-';
}

export function formatReportStatus(value?: string | null) {
  const labels: Record<string, string> = {
    DRAFT: 'Draf', PUBLISHED: 'Dipublikasikan', ARCHIVED: 'Diarsipkan',
  };
  const normalized = value?.trim().toUpperCase();
  return normalized ? labels[normalized] ?? value ?? '-' : '-';
}

export function formatAssessmentType(value?: string | null) {
  const labels: Record<string, string> = {
    DEVELOPMENT_DEMO: 'Evaluasi Semester',
    DEVELOPMENT_SEED: 'Evaluasi Semester',
    FORMATIF: 'Formatif',
    SUMATIF: 'Sumatif',
    PTS: 'Penilaian Tengah Semester',
    PAS: 'Penilaian Akhir Semester',
    PROJECT: 'Proyek',
  };
  const normalized = value?.trim().toUpperCase();
  return normalized ? labels[normalized] ?? value ?? 'Penilaian' : 'Penilaian';
}

export function formatReportType(value?: string | null) {
  const labels: Record<string, string> = {
    PROGRESS_SEMESTER: 'Laporan Perkembangan Semester',
    REPORT_CARD: 'Rapor Semester',
    TAHFIDZ_PROGRESS: 'Laporan Tahfidz',
  };
  const normalized = value?.trim().toUpperCase();
  return normalized ? labels[normalized] ?? value ?? 'Laporan' : 'Laporan';
}

export function formatDonationStatus(value?: string | null) {
  const labels: Record<string, string> = {
    WAITING_PAYMENT: 'Menunggu pembayaran',
    PENDING: 'Menunggu verifikasi',
    PAID: 'Lunas',
    FAILED: 'Gagal',
    EXPIRED: 'Kedaluwarsa',
    REFUNDED: 'Dikembalikan',
    CANCELED: 'Dibatalkan',
    CANCELLED: 'Dibatalkan',
  };
  const normalized = value?.trim().toUpperCase();
  return normalized ? labels[normalized] ?? value ?? '-' : '-';
}

export function formatDevelopmentNote(value?: string | null) {
  if (!value) return '';
  if (/Automated E2E verification/i.test(value)) return 'Setoran tervalidasi pada data pengembangan.';
  if (/Mobile E2E\s+\d+/i.test(value)) return 'Setoran tervalidasi pada pengujian mobile.';
  return value.replace(/^DEVELOPMENT DATA:\s*/i, '');
}

export function friendlyFirstName(value?: string | null) {
  const first = value?.trim().split(/\s+/)[0] ?? '';
  if (!first) return '';
  const generic = new Set(['wali', 'guardian', 'user', 'pengguna', 'demo']);
  return generic.has(first.toLowerCase()) ? '' : first;
}
