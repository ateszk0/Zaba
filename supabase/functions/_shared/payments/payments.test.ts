// Run with: node --test supabase/functions/_shared/payments/
import assert from 'node:assert/strict';
import { test } from 'node:test';

import { FakePaymentProvider, InvalidSessionError } from './fake_provider.ts';
import { WebhookVerificationError } from './provider.ts';
import { checkSignature, hmacSha256Hex, signPayload, timingSafeEqual } from './signing.ts';

const SECRET = 'test-secret-not-used-anywhere-else';
const ORDER = '11111111-1111-4111-8111-111111111111';
const PAYMENT = '22222222-2222-4222-8222-222222222222';
const NOW = 1_800_000_000;

test('HMAC-SHA256 matches the published test vector (RFC 4231, case 2)', async () => {
  assert.equal(
    await hmacSha256Hex('Jefe', 'what do ya want for nothing?'),
    '5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843',
  );
});

test('an empty secret is refused instead of signing with nothing', async () => {
  await assert.rejects(hmacSha256Hex('', 'x'));
  assert.throws(() => new FakePaymentProvider(''));
});

test('timingSafeEqual', () => {
  assert.equal(timingSafeEqual('abc', 'abc'), true);
  assert.equal(timingSafeEqual('abc', 'abd'), false);
  assert.equal(timingSafeEqual('abc', 'abcd'), false);
});

test('a signature checks out for the body it signed', async () => {
  const header = await signPayload(SECRET, '{"a":1}', NOW);
  assert.deepEqual(await checkSignature(SECRET, '{"a":1}', header, NOW), { ok: true });
});

test('a changed body, a wrong secret and a changed timestamp are all refused', async () => {
  const header = await signPayload(SECRET, '{"a":1}', NOW);
  assert.deepEqual(await checkSignature(SECRET, '{"a":2}', header, NOW), { ok: false, reason: 'mismatch' });
  assert.deepEqual(await checkSignature('other', '{"a":1}', header, NOW), { ok: false, reason: 'mismatch' });
  const later = header.replace(`t=${NOW}`, `t=${NOW + 10}`);
  assert.deepEqual(await checkSignature(SECRET, '{"a":1}', later, NOW + 10), { ok: false, reason: 'mismatch' });
});

test('a missing or malformed header is refused', async () => {
  assert.deepEqual(await checkSignature(SECRET, 'x', null, NOW), { ok: false, reason: 'missing' });
  for (const header of ['', 'garbage', 't=abc,v1=zz', `t=${NOW}`, `v1=${'0'.repeat(64)}`]) {
    const result = await checkSignature(SECRET, 'x', header, NOW);
    assert.equal(result.ok, false, header);
  }
});

test('an old or a future event is refused, one inside the window is not', async () => {
  const header = await signPayload(SECRET, 'x', NOW);
  assert.deepEqual(await checkSignature(SECRET, 'x', header, NOW + 299), { ok: true });
  assert.deepEqual(await checkSignature(SECRET, 'x', header, NOW + 301), { ok: false, reason: 'expired' });
  assert.deepEqual(await checkSignature(SECRET, 'x', header, NOW - 301), { ok: false, reason: 'expired' });
});

test('a header with several v1 values accepts the right one (key rotation)', async () => {
  const good = await signPayload(SECRET, 'x', NOW);
  const header = `${good},v1=${'a'.repeat(64)}`;
  assert.deepEqual(await checkSignature(SECRET, 'x', header, NOW), { ok: true });
});

test('a session is genuine for the secret that made it, and carries its payment', async () => {
  const provider = new FakePaymentProvider(SECRET, () => NOW);
  const { token, expiresAt } = await provider.createSession({ paymentId: PAYMENT, orderId: ORDER, amountHuf: 6570 });

  assert.equal(expiresAt, new Date((NOW + 1800) * 1000).toISOString());
  assert.deepEqual(await provider.readSession(token), {
    paymentId: PAYMENT,
    orderId: ORDER,
    amountHuf: 6570,
    expiresAt: NOW + 1800,
  });
});

test('a session is refused when tampered with, forged, expired or malformed', async () => {
  const provider = new FakePaymentProvider(SECRET, () => NOW);
  const { token } = await provider.createSession({ paymentId: PAYMENT, orderId: ORDER, amountHuf: 6570 });
  const [payload, signature] = token.split('.');

  const forged = new FakePaymentProvider('another-secret', () => NOW);
  const forgedToken = (await forged.createSession({ paymentId: PAYMENT, orderId: ORDER, amountHuf: 1 })).token;

  const later = new FakePaymentProvider(SECRET, () => NOW + 1801);
  for (const bad of [`${payload}x.${signature}`, `${payload}.${'0'.repeat(64)}`, forgedToken, 'a.b.c', '', 'nodot']) {
    await assert.rejects(provider.readSession(bad), InvalidSessionError, bad);
  }
  await assert.rejects(later.readSession(token), (e: Error) => e instanceof InvalidSessionError && /expired/.test(e.message));
});

test('the webhook accepts what the provider signed, and tells outcome, order and payment', async () => {
  const provider = new FakePaymentProvider(SECRET, () => NOW);
  const session = await provider.readSession((await provider.createSession({ paymentId: PAYMENT, orderId: ORDER, amountHuf: 1 })).token);

  for (const [outcome, type] of [['succeeded', 'payment.succeeded'], ['failed', 'payment.failed'], ['cancelled', 'payment.cancelled']] as const) {
    const { body, signatureHeader } = await provider.signEvent(session, outcome);
    assert.equal(JSON.parse(body).type, type);
    const event = await provider.verifyWebhook(body, signatureHeader);
    assert.equal(event.outcome, outcome);
    assert.equal(event.orderId, ORDER);
    assert.equal(event.paymentId, PAYMENT);
    assert.match(event.id, /^evt_[0-9a-f]{32}$/);
  }
});

test('every event has its own id, so a retry is a new event, a redelivery the same one', async () => {
  const provider = new FakePaymentProvider(SECRET, () => NOW);
  const session = await provider.readSession((await provider.createSession({ paymentId: PAYMENT, orderId: ORDER, amountHuf: 1 })).token);
  const a = await provider.signEvent(session, 'succeeded');
  const b = await provider.signEvent(session, 'succeeded');
  assert.notEqual(JSON.parse(a.body).id, JSON.parse(b.body).id);
  // The same request delivered twice is verified twice, with the same id.
  assert.equal((await provider.verifyWebhook(a.body, a.signatureHeader)).id, (await provider.verifyWebhook(a.body, a.signatureHeader)).id);
});

test('the webhook refuses unsigned, tampered, foreign, stale and malformed events', async () => {
  const provider = new FakePaymentProvider(SECRET, () => NOW);
  const session = await provider.readSession((await provider.createSession({ paymentId: PAYMENT, orderId: ORDER, amountHuf: 1 })).token);
  const { body, signatureHeader } = await provider.signEvent(session, 'succeeded');

  await assert.rejects(provider.verifyWebhook(body, null), WebhookVerificationError);
  await assert.rejects(provider.verifyWebhook(body.replace('succeeded', 'failed'), signatureHeader), WebhookVerificationError);
  const foreign = new FakePaymentProvider('another-secret', () => NOW);
  await assert.rejects(foreign.verifyWebhook(body, signatureHeader), WebhookVerificationError);
  const late = new FakePaymentProvider(SECRET, () => NOW + 1000);
  await assert.rejects(late.verifyWebhook(body, signatureHeader), WebhookVerificationError);

  // Signed correctly, but not an event we understand.
  for (const bad of ['not json', '{}', JSON.stringify({ id: 'e', type: 'payment.refunded', data: { order_id: ORDER, payment_id: PAYMENT } }),
    JSON.stringify({ id: 'e', type: 'payment.succeeded', data: { order_id: 'x', payment_id: PAYMENT } }),
    JSON.stringify({ id: '', type: 'payment.succeeded', data: { order_id: ORDER, payment_id: PAYMENT } }),
    JSON.stringify({ id: 'e', type: 'payment.succeeded' })]) {
    const header = await signPayload(SECRET, bad, NOW);
    await assert.rejects(provider.verifyWebhook(bad, header), WebhookVerificationError, bad);
  }
});
