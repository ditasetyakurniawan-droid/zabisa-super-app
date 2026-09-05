import {describe, expect, it} from '@jest/globals';
import {nextDonationIdempotencyKey} from './idempotency';

describe('nextDonationIdempotencyKey', () => {
  it('creates distinct bounded keys without a weak random generator', () => {
    const first = nextDonationIdempotencyKey('campaign-1', 1_000);
    const second = nextDonationIdempotencyKey('campaign-1', 1_000);

    expect(first).toMatch(/^donation-campaign-1-1000-\d+$/);
    expect(second).not.toBe(first);
    expect(nextDonationIdempotencyKey('campaign-2')).toMatch(
      /^donation-campaign-2-\d+-\d+$/,
    );
  });
});
