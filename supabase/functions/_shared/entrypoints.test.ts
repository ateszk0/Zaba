// Run with: node --test supabase/functions/_shared/
//
// The three functions start with `Deno.serve(handler)` at the top level, so Node cannot just
// run them. Here `Deno` is a stand-in that remembers the handler and answers `Deno.env.get`
// from a table. Importing each function this way loads it the way the runtime does (syntax,
// imports: a duplicate variable name or a wrong path fails here, not only on the server), and
// the handler can then be called with real `Request` objects.
import assert from 'node:assert/strict';
import { test } from 'node:test';

type Handler = (req: Request) => Promise<Response>;

const env: Record<string, string | undefined> = {};
const handlers: Record<string, Handler> = {};
let loading = '';
(globalThis as unknown as { Deno: unknown }).Deno = {
  serve: (handler: Handler) => {
    handlers[loading] = handler;
  },
  env: { get: (name: string) => env[name] },
};

async function load(name: string): Promise<Handler> {
  if (!handlers[name]) {
    loading = name;
    await import(`../${name}/index.ts`);
  }
  assert.equal(typeof handlers[name], 'function', `${name} registers a handler`);
  return handlers[name];
}

const SECRET = 'a-secret-for-these-tests-only';
function configure(fake: string | undefined) {
  env.SUPABASE_URL = 'http://localhost:9';
  env.FAKE_PAYMENT_WEBHOOK_SECRET = SECRET;
  env.SUPABASE_PUBLISHABLE_KEYS = '{"default":"sb_publishable_test"}';
  env.SUPABASE_SECRET_KEYS = '{"default":"sb_secret_test"}';
  env.FAKE_PAYMENTS_ENABLED = fake;
}
const post = (body: string, headers: Record<string, string> = {}) =>
  new Request('http://localhost/', { method: 'POST', body, headers: { 'Content-Type': 'application/json', ...headers } });
const answer = async (response: Response) => ({ status: response.status, body: await response.json().catch(() => null) });

test('every function loads and registers a handler', async () => {
  for (const name of ['payments-create', 'fake-provider-confirm', 'payments-webhook']) {
    await load(name);
  }
});

test('the fake card step is closed unless the switch is exactly "true"', async () => {
  for (const name of ['payments-create', 'fake-provider-confirm']) {
    const handler = await load(name);
    for (const value of [undefined, '', 'false', 'TRUE', '1']) {
      configure(value);
      const result = await answer(await handler(post('{}')));
      assert.deepEqual(result, { status: 503, body: { error: 'fake_payments_disabled' } }, `${name} with ${JSON.stringify(value)}`);
    }
  }
});

test('with the switch on, payments-create asks for a signed-in customer and a real order id', async () => {
  const handler = await load('payments-create');
  configure('true');
  assert.equal((await answer(await handler(post('{}')))).status, 401);
  assert.deepEqual(await answer(await handler(post('{"order_id":"not-a-uuid"}', { authorization: 'Bearer x' }))), {
    status: 400,
    body: { error: 'invalid_request' },
  });
  assert.equal((await answer(await handler(post('x'.repeat(20_000), { authorization: 'Bearer x' })))).status, 400, 'a huge body is refused');
});

test('fake-provider-confirm refuses what is not a genuine session and an outcome it knows', async () => {
  const handler = await load('fake-provider-confirm');
  configure('true');
  assert.deepEqual(await answer(await handler(post('{"session_token":"x.y","outcome":"approved"}'))), {
    status: 400,
    body: { error: 'invalid_session' },
  });
  for (const outcome of ['constructor', 'toString', '', 'APPROVED', 7]) {
    assert.deepEqual(
      await answer(await handler(post(JSON.stringify({ session_token: 'x.y', outcome })))),
      { status: 400, body: { error: 'invalid_request' } },
      `outcome ${JSON.stringify(outcome)}`,
    );
  }
  assert.equal((await answer(await handler(post('x'.repeat(20_000))))).status, 400, 'a huge body is refused');
});

test('the webhook refuses an unsigned or an oversized request before it touches the database', async () => {
  const handler = await load('payments-webhook');
  configure('true');
  assert.deepEqual(await answer(await handler(post('{}'))), { status: 400, body: { error: 'invalid_webhook' } });
  assert.deepEqual(await answer(await handler(post('{}', { 'x-zaba-signature': 't=1,v1=' + 'a'.repeat(64) }))), {
    status: 400,
    body: { error: 'invalid_webhook' },
  });
  assert.deepEqual(await answer(await handler(post('x'.repeat(20_000)))), { status: 413, body: { error: 'invalid_webhook' } });
  assert.equal((await handler(new Request('http://localhost/', { method: 'GET' }))).status, 405);
});

test('a function without its secret refuses to work', async () => {
  const handler = await load('payments-webhook');
  configure('true');
  env.FAKE_PAYMENT_WEBHOOK_SECRET = undefined;
  assert.deepEqual(await answer(await handler(post('{}'))), { status: 500, body: { error: 'not_configured' } });
});
