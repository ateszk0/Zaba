// Switches that are read from the environment of a function. No Deno API here, so
// the rules are tested under Node.

/**
 * Whether the demo's fake payment flow may run (`FAKE_PAYMENTS_ENABLED`). It is OFF
 * unless the variable is exactly `true`. The fake card step lets the app itself report
 * that a card was approved, which is right for a demo and would let anybody mark their own
 * order as paid on a real shop: so the flow must be switched on deliberately, and a server
 * that goes live with real payments just leaves the variable out.
 */
export function fakePaymentsEnabled(value: string | undefined): boolean {
  return value === 'true';
}
