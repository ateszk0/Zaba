// Starts a payment for the signed-in customer's order and opens a payment
// session with the provider. The database function does the real checks
// (signed in, the customer's own order, still waiting for payment); this
// function only passes the customer's identity on and adds the provider session.

import { FakePaymentProvider } from '../_shared/payments/fake_provider.ts';
import { fakePaymentsEnabled } from '../_shared/flags.ts';
import { apiKey, json, preflight, readEnv, readJsonBody, restHeaders, UUID } from '../_shared/http.ts';

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return preflight();
  }
  if (req.method !== 'POST') {
    return json({ error: 'method_not_allowed' }, 405);
  }
  if (!fakePaymentsEnabled(Deno.env.get('FAKE_PAYMENTS_ENABLED'))) {
    // The only payment provider yet is the demo's; see _shared/flags.ts.
    return json({ error: 'fake_payments_disabled' }, 503);
  }
  const env = readEnv('payments-create', ['SUPABASE_URL', 'FAKE_PAYMENT_WEBHOOK_SECRET']);
  const publishableKey = apiKey('payments-create', 'publishable');
  if (!env || !publishableKey) {
    return json({ error: 'not_configured' }, 500);
  }
  const authorization = req.headers.get('authorization');
  if (!authorization) {
    return json({ error: 'not_authenticated' }, 401);
  }

  const body = await readJsonBody(req);
  const orderId = body?.order_id;
  if (typeof orderId !== 'string' || !UUID.test(orderId)) {
    return json({ error: 'invalid_request' }, 400);
  }

  // Runs as the customer: the caller's own token, not a privileged key.
  const response = await fetch(`${env.SUPABASE_URL}/rest/v1/rpc/start_payment`, {
    method: 'POST',
    headers: restHeaders(publishableKey, { Authorization: authorization }),
    body: JSON.stringify({ p_order_id: orderId }),
  });
  if (!response.ok) {
    const failure = await response.json().catch(() => ({}));
    // A guest (the anonymous role) is not allowed to call start_payment at all.
    if (failure.message === 'not_authenticated' || failure.code === '42501') {
      return json({ error: 'not_authenticated' }, 401);
    }
    if (failure.message === 'order_not_found') {
      return json({ error: 'order_not_found' }, 404);
    }
    if (failure.message === 'order_not_payable') {
      return json({ error: 'order_not_payable' }, 409);
    }
    console.error('payments-create: start_payment failed', response.status, failure.code, failure.message);
    return json({ error: 'payment_start_failed' }, 502);
  }
  const payment = await response.json();

  const provider = new FakePaymentProvider(env.FAKE_PAYMENT_WEBHOOK_SECRET);
  const session = await provider.createSession({
    paymentId: payment.payment_id,
    orderId,
    amountHuf: payment.amount_huf,
  });
  return json({
    payment_id: payment.payment_id,
    amount_huf: payment.amount_huf,
    currency: payment.currency,
    provider: provider.name,
    session_token: session.token,
    expires_at: session.expiresAt,
  });
});
