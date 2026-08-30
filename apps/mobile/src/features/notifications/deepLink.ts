export type ParsedZabisaDeepLink =
  | {kind: 'guardian'; studentId: string; resource: 'tahfidz' | 'academic'; resourceId: string}
  | {kind: 'legacy-guardian'; resource: 'tahfidz' | 'academic'; resourceId: string}
  | {kind: 'kajian'; kajianId: string}
  | {kind: 'unknown'};

export function parseZabisaDeepLink(value?: string | null): ParsedZabisaDeepLink {
  const link = value?.trim() ?? '';
  if (!link) return {kind: 'unknown'};

  const guardian = link.match(/^zabisa:\/\/guardian\/students\/([^/?#]+)\/(tahfidz|academic)\/([^/?#]+)/i);
  if (guardian) {
    return {
      kind: 'guardian',
      studentId: guardian[1],
      resource: guardian[2].toLowerCase() as 'tahfidz' | 'academic',
      resourceId: guardian[3],
    };
  }

  const legacy = link.match(/^zabisa:\/\/(tahfidz|academic)\/([^/?#]+)/i);
  if (legacy) {
    return {
      kind: 'legacy-guardian',
      resource: legacy[1].toLowerCase() as 'tahfidz' | 'academic',
      resourceId: legacy[2],
    };
  }

  const kajian = link.match(/^zabisa:\/\/kajian\/([^/?#]+)/i);
  if (kajian) return {kind: 'kajian', kajianId: kajian[1]};

  return {kind: 'unknown'};
}

export function notificationTypeLabel(value?: string | null) {
  const type = value?.trim().toUpperCase();
  const labels: Record<string, string> = {
    TAHFIDZ: 'Tahfidz',
    KAJIAN: 'Kajian',
    GRADE: 'Akademik',
    ACADEMIC: 'Akademik',
    REPORT: 'Rapor',
    ATTENDANCE: 'Kehadiran',
    GENERAL: 'Informasi',
    ANNOUNCEMENT: 'Pengumuman',
    REMINDER: 'Pengingat',
    DONATION: 'Donasi',
  };
  return type ? labels[type] ?? type : 'Informasi';
}
