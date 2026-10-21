// The boundary between Zaba and a payment provider. The order logic only ever
// sees `ProviderEvent`s that `verifyWebhook` has authenticated, so replacing the
// fake provider with a real one (Barion, Stripe, SimplePay) means writing one
// more class that implements this interface.

/** How a payment attempt ended, in the words the database uses. */
export type PaymentOutcome = 'succeeded' | 'failed' | 'cancelled';

/** What the provider reports. Only ever built from a verified webhook. */
export type ProviderEvent = {
  /** Unique per event; a provider may deliver the same event more than once. */
  id: string;
  outcome: PaymentOutcome;
  orderId: string;
  paymentId: string;
};

export type PaymentSession = {
  /** What the customer's app hands to the provider's payment page. */
  token: string;
  expiresAt: string;
};

export class WebhookVerificationError extends Error {
  reason: string;

  constructor(reason: string) {
    super(`Webhook rejected: ${reason}`);
    this.name = 'WebhookVerificationError';
    this.reason = reason;
  }
}

export interface PaymentProvider {
  readonly name: string;

  /** Opens a payment session for one payment attempt. */
  createSession(input: { paymentId: string; orderId: string; amountHuf: number }): Promise<PaymentSession>;

  /**
   * Authenticates a webhook request (signature, freshness) and returns the
   * event it carries. Throws `WebhookVerificationError` for anything else.
   */
  verifyWebhook(rawBody: string, signatureHeader: string | null): Promise<ProviderEvent>;
}
