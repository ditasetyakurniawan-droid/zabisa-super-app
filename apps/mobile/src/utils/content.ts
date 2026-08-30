const CONTENT_TYPE_ALIASES: Record<string, string> = {
  news: 'NEWS',
  berita: 'NEWS',
  program: 'PROGRAM',
  programs: 'PROGRAM',
  profile: 'PROFILE',
  tentang: 'PROFILE',
  gallery: 'GALLERY',
  galeri: 'GALLERY',
  article: 'ARTICLE',
  articles: 'ARTICLE',
  announcement: 'ANNOUNCEMENT',
  banner: 'BANNER',
};

const CONTENT_TYPE_LABELS: Record<string, string> = {
  NEWS: 'Berita',
  PROGRAM: 'Program',
  PROFILE: 'Profil',
  GALLERY: 'Galeri',
  ARTICLE: 'Artikel',
  ANNOUNCEMENT: 'Pengumuman',
  EMERGENCY: 'Informasi Penting',
  BANNER: 'Banner',
};

export function normalizeContentType(value?: string) {
  const input = String(value ?? '').trim();
  if (!input) return '';
  const lower = input.toLowerCase();
  return CONTENT_TYPE_ALIASES[lower] ?? input.toUpperCase();
}

export function contentTypeLabel(value?: string) {
  const normalized = normalizeContentType(value);
  return CONTENT_TYPE_LABELS[normalized] ?? (normalized || 'Informasi');
}
