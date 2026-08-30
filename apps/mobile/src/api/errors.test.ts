import {describe, expect, it} from '@jest/globals';
import {ApiError, userMessage} from './errors';

describe('userMessage', () => {
  it('maps session expiry without exposing backend details', () => {
    expect(userMessage(new ApiError('token signature invalid', 401))).toBe('Sesi Anda sudah berakhir. Silakan login kembali.');
  });

  it('maps authorization and server errors to safe messages', () => {
    expect(userMessage(new ApiError('forbidden', 403))).toContain('tidak memiliki akses');
    expect(userMessage(new ApiError('sql connection refused', 500))).toContain('Layanan sedang mengalami kendala');
  });

  it('maps network errors', () => {
    expect(userMessage(new Error('Network request failed'))).toContain('Tidak dapat terhubung');
  });
});
