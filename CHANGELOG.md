## 0.1.0

Initial release.

- HTTP transport (`StripeClient`) ported from `stripe-node` 19.3.1: jittered
  exponential backoff, `Retry-After` and `stripe-should-retry` support, and an
  idempotency key on every POST. Request bodies follow Stripe's bracket-notation
  form encoding, verified against fixtures captured from `stripe-node` itself.
- Sealed `StripeError` hierarchy covering every error type the API returns.
- `StripeWebhooks.constructEvent` for verifying and decoding webhook
  deliveries, with constant-time comparison and secret rotation.
- Operations on `checkout.sessions`, `billingPortal.sessions`, `customers`,
  `subscriptions`, `promotionCodes`, `invoices`, `prices` and `products` — see
  the README for the exact list.
- `Subscription.currentPeriodStart` / `currentPeriodEnd` read the period off
  `SubscriptionItem`, where Stripe moved it in API version `2025-03-31.basil`.
- `Invoice.totalTaxAmount` reads either `total_taxes` or the legacy
  `total_tax_amounts`, whichever shape the account's API version returns.
