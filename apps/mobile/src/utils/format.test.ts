import {describe, expect, it} from '@jest/globals';
import {
  formatActivityType,
  formatAttendanceStatus,
  formatCurrencyID,
  formatDateID,
  formatDateTimeID,
  formatDevelopmentNote,
  formatReportStatus, formatAssessmentType, formatReportType, formatDonationStatus,
  friendlyFirstName,
} from './format';

describe('Indonesian presentation formatters', () => {
  it('formats currency without exposing raw numeric presentation', () => {
    expect(formatCurrencyID(1250000)).toBe('Rp 1.250.000');
  });

  it('formats ISO date for Indonesian readers', () => {
    expect(formatDateID('2026-08-30')).toContain('30 Agustus 2026');
  });

  it('formats date-time with a compact Indonesian separator', () => {
    expect(formatDateTimeID('2026-08-30T14:34:00+07:00')).toContain('•');
  });

  it('maps domain statuses to human-readable Indonesian labels', () => {
    expect(formatActivityType('MURAJAAH')).toBe('Murajaah');
    expect(formatAttendanceStatus('PRESENT')).toBe('Hadir');
    expect(formatAttendanceStatus('PERMITTED')).toBe('Izin');
    expect(formatReportStatus('PUBLISHED')).toBe('Dipublikasikan');
    expect(formatAssessmentType('DEVELOPMENT_DEMO')).toBe('Evaluasi Semester');
    expect(formatReportType('REPORT_CARD')).toBe('Rapor Semester');
  });

  it('normalizes development-only notes and generic greeting names', () => {
    expect(formatDevelopmentNote('Automated E2E verification')).toContain('data pengembangan');
    expect(formatDevelopmentNote('DEVELOPMENT DATA: Hadir tepat waktu')).toBe('Hadir tepat waktu');
    expect(friendlyFirstName('Wali')).toBe('');
    expect(friendlyFirstName('Fulan Ahmad')).toBe('Fulan');
  });
});


describe('donation status formatter', () => {
  it('uses Indonesian labels for demo transactions', () => {
    expect(formatDonationStatus('PAID')).toBe('Lunas');
    expect(formatDonationStatus('WAITING_PAYMENT')).toBe('Menunggu pembayaran');
  });
});
