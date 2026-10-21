// HMAC-SHA256 signing for payment webhooks, written against the Web Crypto API
// only, so the same file runs in the Edge Runtime (Deno) and in Node (tests).

const encoder = new TextEncoder();

function toHex(bytes: Uint8Array): string {
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, '0')).join('');
}

export async function hmacSha256Hex(secret: string, message: string): Promise<string> {
  if (!secret) {
    throw new Error('A signing secret is required');
  }
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign('HMAC', key, encoder.encode(message));
  return toHex(new Uint8Array(signature));
}

/** Compares two strings without stopping at the first difference. */
export function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) {
    return false;
  }
  let difference = 0;
  for (let i = 0; i < a.length; i++) {
    difference |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return difference === 0;
}

/**
 * The value of the signature header: `t=<unix seconds>,v1=<hex>`, where the
 * signature covers `<t>.<body>`. The timestamp is inside the signed text, so it
 * cannot be changed to replay an old event as a new one.
 */
export async function signPayload(secret: string, body: string, timestampSec: number): Promise<string> {
  const signature = await hmacSha256Hex(secret, `${timestampSec}.${body}`);
  return `t=${timestampSec},v1=${signature}`;
}

export type SignatureCheck =
  | { ok: true }
  | { ok: false; reason: 'missing' | 'malformed' | 'expired' | 'mismatch' };

/**
 * Checks the header against the body. An event older (or newer) than
 * `toleranceSec` is refused, which limits how long a captured request stays
 * useful; the event id makes processing idempotent on top of that.
 */
export async function checkSignature(
  secret: string,
  body: string,
  header: string | null,
  nowSec: number,
  toleranceSec = 300,
): Promise<SignatureCheck> {
  if (!header) {
    return { ok: false, reason: 'missing' };
  }
  let timestamp: number | undefined;
  const candidates: string[] = [];
  for (const part of header.split(',')) {
    const separator = part.indexOf('=');
    if (separator < 0) {
      continue;
    }
    const name = part.slice(0, separator).trim();
    const value = part.slice(separator + 1).trim();
    if (name === 't' && /^\d{1,12}$/.test(value)) {
      timestamp = Number(value);
    } else if (name === 'v1' && /^[0-9a-f]{64}$/.test(value)) {
      candidates.push(value);
    }
  }
  if (timestamp === undefined || candidates.length === 0) {
    return { ok: false, reason: 'malformed' };
  }
  if (Math.abs(nowSec - timestamp) > toleranceSec) {
    return { ok: false, reason: 'expired' };
  }
  const expected = await hmacSha256Hex(secret, `${timestamp}.${body}`);
  // Every candidate is compared, so the time taken does not tell which matched.
  let matched = false;
  for (const candidate of candidates) {
    if (timingSafeEqual(candidate, expected)) {
      matched = true;
    }
  }
  return matched ? { ok: true } : { ok: false, reason: 'mismatch' };
}
