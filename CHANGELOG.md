## 0.4.1

- Export the Checkout Session option classes and the invoice tax types added
  in 0.4.0. They were implemented but missing from the barrel, so callers
  could not name them without reaching into `src/`.

## 0.4.0

- Add the remaining Checkout Session create options the Fullphysio checkout
  flow needs: `phoneNumberCollection`, `taxIdCollection`, `automaticTax`,
  `customerUpdate` and `billingAddressCollection`.
- Decode `total_taxes` on `Invoice` alongside the legacy `total_tax_amounts`.
  Stripe reshaped that field, so summing only the old list silently reports
  zero tax on newer API versions; the new `totalTaxAmount` getter reads
  whichever shape the account actually returns.

## 0.3.0

- Add the resources needed to port the Cloud Functions billing surface off
  `stripe-node`: `Customer`, `Subscription` (with `SubscriptionItem`, whose
  `currentPeriodStart`/`currentPeriodEnd` fix the crash `client_stripe` hit
  when Stripe removed those fields from the subscription itself),
  `Invoice`, `PromotionCode`, `Coupon`, `Discount`, `Price`, `Plan`,
  `Product`, `CheckoutSession`, and `Event`.
- Add `StripeClient.customers`, `.subscriptions`, `.invoices`,
  `.promotionCodes`, `.prices`, `.products`, and `.checkout.sessions`.
- Add `StripeWebhooks.constructEvent` for verifying and decoding webhook
  deliveries.

## 0.2.1

- Add the missing `locale` parameter to `BillingPortalSessionCreateParams`,
  so callers can override the Billing Portal UI language instead of always
  getting Stripe's auto-detected one.

## 0.2.0

- Add the HTTP transport: `StripeClient`, with automatic retries (jittered
  exponential backoff, `Retry-After` and `stripe-should-retry` support) and
  idempotency keys on every POST.
- Add the Billing Portal Session resource:
  `StripeClient.billingPortal.sessions.create`.

## 0.1.0

- Initial release.
