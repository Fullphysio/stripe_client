## 0.2.0

- Add the HTTP transport: `StripeClient`, with automatic retries (jittered
  exponential backoff, `Retry-After` and `stripe-should-retry` support) and
  idempotency keys on every POST.
- Add the Billing Portal Session resource:
  `StripeClient.billingPortal.sessions.create`.

## 0.1.0

- Initial release.
