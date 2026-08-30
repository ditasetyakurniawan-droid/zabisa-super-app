export class ApiError extends Error {
  constructor(
    message: string,
    public readonly status?: number,
    public readonly code?: string,
    public readonly traceId?: string,
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

export function userMessage(error: unknown) {
  if (error instanceof ApiError) {
    if (error.status === 401) return 'Sesi Anda sudah berakhir. Silakan login kembali.';
    if (error.status === 403) return 'Anda tidak memiliki akses ke data ini.';
    if (error.status === 404) return 'Data yang diminta belum tersedia.';
    if (error.status && error.status >= 500) return 'Layanan sedang mengalami kendala. Silakan coba lagi.';
    return error.message || 'Permintaan belum dapat diproses.';
  }
  if (error instanceof Error && /abort|network|fetch/i.test(error.message)) {
    return 'Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.';
  }
  return 'Terjadi kendala. Silakan coba lagi.';
}
