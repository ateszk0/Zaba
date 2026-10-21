// Run with: node --test supabase/functions/_shared/
import assert from 'node:assert/strict';
import { test } from 'node:test';

import { readJsonBody, readTextLimited } from './http.ts';

const post = (body: BodyInit | null, headers: Record<string, string> = {}) =>
  new Request('http://localhost/', { method: 'POST', body, headers });

test('a small body is read', async () => {
  assert.equal(await readTextLimited(post('{"a":1}')), '{"a":1}');
  assert.deepEqual(await readJsonBody(post('{"a":1}')), { a: 1 });
});

test('a body without content is the empty text, and not a JSON object', async () => {
  assert.equal(await readTextLimited(post(null)), '');
  assert.equal(await readJsonBody(post(null)), null);
});

test('a body over the limit is refused, whether or not it admits its size', async () => {
  const big = 'x'.repeat(2_000);
  assert.equal(await readTextLimited(post(big), 1_000), null);
  // The declared size alone is enough to refuse it, before anything is read.
  assert.equal(await readTextLimited(post('tiny', { 'content-length': '999999' }), 1_000), null);
  // A stream that never says how long it is, and goes over, is given up on.
  const stream = new ReadableStream({
    start(controller) {
      controller.enqueue(new TextEncoder().encode(big));
      controller.close();
    },
  });
  assert.equal(await readTextLimited(new Request('http://localhost/', { method: 'POST', body: stream, duplex: 'half' } as RequestInit), 1_000), null);
});

test('the limit is inclusive', async () => {
  assert.equal(await readTextLimited(post('x'.repeat(1_000)), 1_000), 'x'.repeat(1_000));
  assert.equal(await readTextLimited(post('x'.repeat(1_001)), 1_000), null);
});

test('only a JSON object is accepted as a JSON body', async () => {
  assert.equal(await readJsonBody(post('not json')), null);
  assert.equal(await readJsonBody(post('[1,2]')), null);
  assert.equal(await readJsonBody(post('"text"')), null);
  assert.equal(await readJsonBody(post('null')), null);
  assert.deepEqual(await readJsonBody(post('{}')), {});
});
