// Run with: node --test supabase/functions/_shared/
import assert from 'node:assert/strict';
import { test } from 'node:test';

import { keyFromDictionary, pickKey } from './keys.ts';

test('the default key is read from the platform dictionary', () => {
  assert.equal(keyFromDictionary('{"default": "sb_publishable_abc"}'), 'sb_publishable_abc');
  assert.equal(keyFromDictionary('{"web": "x", "default": "y"}'), 'y');
  assert.equal(keyFromDictionary('{"web": "x"}', 'web'), 'x');
});

test('an empty, missing or broken dictionary has no key', () => {
  for (const bad of [undefined, '', '{}', '{"default": ""}', '{"default": 5}', 'not json', '[]', 'null', '"text"']) {
    assert.equal(keyFromDictionary(bad), undefined, String(bad));
  }
});

test('the new key wins over the legacy one', () => {
  assert.equal(pickKey('{"default": "new"}', 'legacy'), 'new');
});

test('the legacy key is used when the new one is not there (the self-hosted stack passes an empty one)', () => {
  assert.equal(pickKey('{"default": ""}', 'legacy'), 'legacy');
  assert.equal(pickKey(undefined, 'legacy'), 'legacy');
});

test('no key at all is undefined, never an empty string', () => {
  assert.equal(pickKey(undefined, undefined), undefined);
  assert.equal(pickKey('{}', ''), undefined);
});
