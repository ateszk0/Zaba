// Receives the payment provider's events. It is the ONLY way an order becomes
// paid: the customer's app can ask for a payment and report a card outcome to the
// provider, but only an event that passes the signature check below reaches
// `apply_payment_event` (which only this function's service-role key may call).
//
// Idempotent: the database records every event id once, so a provider that
// delivers the same event twice changes nothing the second time.

import { FakePaymentProvider } from '../_shared/payments/fake_provider.ts';
import { WebhookVerificationError } from '../_shared/payments/provider.ts';
import { apiKey, json, readEnv, readTextLimited, restHeaders } from '../_shared/http.ts';

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return json({ error: 'method_not_allowed' }, 405);
  }
  const env = readEnv('payments-webhook', ['SUPABASE_URL', 'FAKE_PAYMENT_WEBHOOK_SECRET']);
  const secretKey = apiKey('payments-webhook', 'secret');
  if (!env || !secretKey) {
    return json({ error: 'not_configured' }, 500);
  }

  const rawBody = await readTextLimited(req);
  if (rawBody === null) {
    return json({ error: 'invalid_webhook' }, 413);
  }

  const provider = new FakePaymentProvider(env.FAKE_PAYMENT_WEBHOOK_SECRET);
  let event;
  try {
    event = await provider.verifyWebhook(rawBody, req.headers.get('x-zaba-signature'));
  } catch (error) {
    if (error instanceof WebhookVerificationError) {
      // The reason goes to the log only: it must not help someone forge events.
      console.warn('payments-webhook:', error.message);
      return json({ error: 'invalid_webhook' }, 400);
    }
    throw error;
  }

  const response = await fetch(`${env.SUPABASE_URL}/rest/v1/rpc/apply_payment_event`, {
    method: 'POST',
    headers: restHeaders(secretKey),
    body: JSON.stringify({
      p_provider: provider.name,
      p_event_id: event.id,
      p_order_id: event.orderId,
      p_type: event.outcome,
      p_payload: { payment_id: event.paymentId, event: JSON.parse(rawBody) },
    }),
  });
  if (!response.ok) {
    const failure = await response.json().catch(() => ({}));
    console.error('payments-webhook: apply_payment_event failed', response.status, failure.code, failure.message);
    // A server error makes a real provider deliver the event again later.
    return json({ error: 'apply_failed' }, 500);
  }
  return json(await response.json());
});
