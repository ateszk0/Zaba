// The demo's payment provider. It plays both sides of a real one: it hands out
// payment sessions, and (`signEvent`) it signs the events its backend would
// send to the webhook. The webhook side (`verifyWebhook`) is the real thing:
// signature, freshness, strict parsing.
//
// What is fake: `fake-provider-confirm` takes the card outcome from the app. A
// real provider takes the card itself on its own page and decides there.

import { checkSignature, hmacSha256Hex, signPayload, timingSafeEqual } from './signing.ts';
import { WebhookVerificationError } from './provider.ts';
import type { PaymentOutcome, PaymentProvider, PaymentSession, ProviderEvent } from './provider.ts';

const SESSION_TTL_SEC = 30 * 60;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
// A Map, not an object: a lookup in an object also finds what every object has
// ("constructor", "toString"), which is not an event type.
const EVENT_TYPES = new Map<string, PaymentOutcome>([
  ['payment.succeeded', 'succeeded'],
  ['payment.failed', 'failed'],
  ['payment.cancelled', 'cancelled'],
]);

export class InvalidSessionError extends Error {
  constructor(reason: string) {
    super(`Payment session rejected: ${reason}`);
    this.name = 'InvalidSessionError';
  }
}

export type SessionDetails = { paymentId: string; orderId: string; amountHuf: number; expiresAt: number };

function base64UrlEncode(text: string): string {
  const bytes = new TextEncoder().encode(text);
  let binary = '';
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary).replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/, '');
}

function base64UrlDecode(text: string): string {
  const padded = text.replaceAll('-', '+').replaceAll('_', '/').padEnd(Math.ceil(text.length / 4) * 4, '=');
  const binary = atob(padded);
  return new TextDecoder().decode(Uint8Array.from(binary, (char) => char.charCodeAt(0)));
}

function randomHex(bytes: number): string {
  return Array.from(crypto.getRandomValues(new Uint8Array(bytes)), (b) => b.toString(16).padStart(2, '0')).join('');
}

export class FakePaymentProvider implements PaymentProvider {
  readonly name = 'fake';
  #secret: string;
  #now: () => number;

  constructor(secret: string, now: () => number = () => Math.floor(Date.now() / 1000)) {
    if (!secret) {
      throw new Error('The fake provider needs its secret');
    }
    this.#secret = secret;
    this.#now = now;
  }

  async createSession(input: { paymentId: string; orderId: string; amountHuf: number }): Promise<PaymentSession> {
    const expires = this.#now() + SESSION_TTL_SEC;
    const payload = base64UrlEncode(
      JSON.stringify({ v: 1, p: input.paymentId, o: input.orderId, a: input.amountHuf, e: expires, n: randomHex(8) }),
    );
    const signature = await hmacSha256Hex(this.#secret, `session:${payload}`);
    return { token: `${payload}.${signature}`, expiresAt: new Date(expires * 1000).toISOString() };
  }

  /** Throws `InvalidSessionError` unless the token is genuine and not expired. */
  async readSession(token: string): Promise<SessionDetails> {
    const parts = token.split('.');
    if (parts.length !== 2) {
      throw new InvalidSessionError('malformed');
    }
    const [payload, signature] = parts;
    const expected = await hmacSha256Hex(this.#secret, `session:${payload}`);
    if (!timingSafeEqual(signature, expected)) {
      throw new InvalidSessionError('signature');
    }
    let data: Record<string, unknown>;
    try {
      data = JSON.parse(base64UrlDecode(payload));
    } catch {
      throw new InvalidSessionError('malformed');
    }
    const { p, o, a, e } = data;
    if (typeof p !== 'string' || typeof o !== 'string' || typeof a !== 'number' || typeof e !== 'number') {
      throw new InvalidSessionError('malformed');
    }
    if (e < this.#now()) {
      throw new InvalidSessionError('expired');
    }
    return { paymentId: p, orderId: o, amountHuf: a, expiresAt: e };
  }

  /** The signed webhook request this provider's backend sends for [outcome]. */
  async signEvent(
    session: SessionDetails,
    outcome: PaymentOutcome,
  ): Promise<{ body: string; signatureHeader: string }> {
    const timestamp = this.#now();
    const body = JSON.stringify({
      id: `evt_${randomHex(16)}`,
      type: `payment.${outcome}`,
      created: timestamp,
      data: { order_id: session.orderId, payment_id: session.paymentId },
    });
    return { body, signatureHeader: await signPayload(this.#secret, body, timestamp) };
  }

  async verifyWebhook(rawBody: string, signatureHeader: string | null): Promise<ProviderEvent> {
    const check = await checkSignature(this.#secret, rawBody, signatureHeader, this.#now());
    if (!check.ok) {
      throw new WebhookVerificationError(check.reason);
    }
    let event: Record<string, unknown>;
    try {
      event = JSON.parse(rawBody);
    } catch {
      throw new WebhookVerificationError('body');
    }
    const data = event.data as Record<string, unknown> | undefined;
    const outcome = typeof event.type === 'string' ? EVENT_TYPES.get(event.type) : undefined;
    if (
      typeof event.id !== 'string' || event.id.length < 1 || event.id.length > 100 ||
      outcome === undefined || !data ||
      typeof data.order_id !== 'string' || !UUID.test(data.order_id) ||
      typeof data.payment_id !== 'string' || !UUID.test(data.payment_id)
    ) {
      throw new WebhookVerificationError('event');
    }
    return { id: event.id, outcome, orderId: data.order_id, paymentId: data.payment_id };
  }
}
