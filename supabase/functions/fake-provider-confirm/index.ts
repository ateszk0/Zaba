// The backend of the FAKE payment provider. In production this does not exist:
// the real provider shows its own payment page, takes the card, and its backend
// calls our webhook. Here the app reports the outcome of the fake card step,
// and this function plays the provider's backend: it checks the payment session
// it handed out, signs an event and delivers it to the webhook over HTTP, so
// everything after this point is the real path.

import { FakePaymentProvider, InvalidSessionError } from '../_shared/payments/fake_provider.ts';
import type { PaymentOutcome } from '../_shared/payments/provider.ts';
import { fakePaymentsEnabled } from '../_shared/flags.ts';
import { json, preflight, readEnv, readJsonBody } from '../_shared/http.ts';

/** What the fake card page can report. (A Map: an object would also "know" constructor and toString.) */
const OUTCOMES = new Map<string, PaymentOutcome>([
  ['approved', 'succeeded'],
  ['declined', 'failed'],
  ['cancelled', 'cancelled'],
]);

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return preflight();
  }
  if (req.method !== 'POST') {
    return json({ error: 'method_not_allowed' }, 405);
  }
  if (!fakePaymentsEnabled(Deno.env.get('FAKE_PAYMENTS_ENABLED'))) {
    // This function lets the app itself say that a card was approved: demo only.
    return json({ error: 'fake_payments_disabled' }, 503);
  }
  const env = readEnv('fake-provider-confirm', ['SUPABASE_URL', 'FAKE_PAYMENT_WEBHOOK_SECRET']);
  if (!env) {
    return json({ error: 'not_configured' }, 500);
  }

  const input = await readJsonBody(req);
  const sessionToken = input?.session_token;
  const outcome = typeof input?.outcome === 'string' ? OUTCOMES.get(input.outcome) : undefined;
  if (typeof sessionToken !== 'string' || outcome === undefined) {
    return json({ error: 'invalid_request' }, 400);
  }

  const provider = new FakePaymentProvider(env.FAKE_PAYMENT_WEBHOOK_SECRET);
  let session;
  try {
    session = await provider.readSession(sessionToken);
  } catch (error) {
    if (error instanceof InvalidSessionError) {
      return json({ error: 'invalid_session' }, 400);
    }
    throw error;
  }

  const { body, signatureHeader } = await provider.signEvent(session, outcome);
  const delivery = await fetch(`${env.SUPABASE_URL}/functions/v1/payments-webhook`, {
    method: 'POST',
    // No Supabase credentials: the webhook takes no platform token (a real
    // provider has none to send); the signature is its credential.
    headers: {
      'Content-Type': 'application/json',
      'x-zaba-signature': signatureHeader,
    },
    body,
  });
  if (!delivery.ok) {
    console.error('fake-provider-confirm: the webhook answered', delivery.status);
    return json({ error: 'webhook_failed' }, 502);
  }
  return json({ accepted: true });
});
