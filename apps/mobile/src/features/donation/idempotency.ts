let sequence = 0;

export function nextDonationIdempotencyKey(campaignId: string, now = Date.now()) {
  sequence += 1;
  return `donation-${campaignId}-${now}-${sequence}`;
}
