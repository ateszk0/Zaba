// Run with: node --test supabase/functions/_shared/
import assert from 'node:assert/strict';
import { test } from 'node:test';

import { fakePaymentsEnabled } from './flags.ts';

test('the fake payment flow runs only when the variable is exactly "true"', () => {
  assert.equal(fakePaymentsEnabled('true'), true);
  for (const off of [undefined, '', 'false', 'TRUE', 'True', '1', 'yes', ' true', 'true ']) {
    assert.equal(fakePaymentsEnabled(off), false, `${JSON.stringify(off)} must not switch it on`);
  }
});
