import {describe, expect, it} from '@jest/globals';
import {contentTypeLabel, normalizeContentType} from './content';

describe('content type mapping', () => {
  it.each([
    ['news', 'NEWS'],
    ['programs', 'PROGRAM'],
    ['profile', 'PROFILE'],
    ['gallery', 'GALLERY'],
    ['ARTICLE', 'ARTICLE'],
  ])('maps %s to backend enum %s', (input, expected) => {
    expect(normalizeContentType(input)).toBe(expected);
  });

  it('renders Indonesian content labels', () => {
    expect(contentTypeLabel('NEWS')).toBe('Berita');
    expect(contentTypeLabel('PROGRAM')).toBe('Program');
    expect(contentTypeLabel('GALLERY')).toBe('Galeri');
  });
});
