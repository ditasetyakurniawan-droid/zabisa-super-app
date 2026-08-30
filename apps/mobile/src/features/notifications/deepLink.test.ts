import {describe, expect, it} from '@jest/globals';
import {notificationTypeLabel, parseZabisaDeepLink} from './deepLink';

describe('Zabisa deep links', () => {
  it('parses guardian resource links with object context', () => {
    expect(parseZabisaDeepLink('zabisa://guardian/students/student-1/tahfidz/entry-1')).toEqual({
      kind: 'guardian', studentId: 'student-1', resource: 'tahfidz', resourceId: 'entry-1',
    });
  });

  it('keeps backward compatibility for legacy links', () => {
    expect(parseZabisaDeepLink('zabisa://academic/grade-1')).toEqual({
      kind: 'legacy-guardian', resource: 'academic', resourceId: 'grade-1',
    });
  });

  it('parses kajian links and rejects unknown schemes', () => {
    expect(parseZabisaDeepLink('zabisa://kajian/kajian-1')).toEqual({kind: 'kajian', kajianId: 'kajian-1'});
    expect(parseZabisaDeepLink('https://example.com')).toEqual({kind: 'unknown'});
  });

  it('localizes notification categories', () => {
    expect(notificationTypeLabel('ACADEMIC')).toBe('Akademik');
    expect(notificationTypeLabel('TAHFIDZ')).toBe('Tahfidz');
  });
});


describe('notification type labels for demo data', () => {
  it('localizes general development notifications', () => {
    expect(notificationTypeLabel('GENERAL')).toBe('Informasi');
    expect(notificationTypeLabel('ANNOUNCEMENT')).toBe('Pengumuman');
    expect(notificationTypeLabel('REMINDER')).toBe('Pengingat');
    expect(notificationTypeLabel('DONATION')).toBe('Donasi');
  });
});
