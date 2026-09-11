# stripe_client

A pure Dart client for the Stripe API. Runs on Dart servers, CLIs and Flutter
apps — there is no Flutter dependency, and no code generation step for you.

```dart
final stripe = StripeClient(apiKey: Platform.environment['STRIPE_API_KEY']!);

final session = await stripe.checkout.sessions.create(
  CheckoutSessionCreateParams(
    mode: CheckoutSessionMode.subscription,
    lineItems: [CheckoutSessionLineItemParams(price: priceId, quantity: 1)],
    successUrl: 'https://example.com/done',
    cancelUrl: 'https://example.com/cancel',
  ),
);
```

## Why this exists

No maintained Dart Stripe client covers the server API. The two community
packages predate the `promotionCodes` and `invoices` resources, and the one
that is complete was produced by a closed generator, so it cannot be
regenerated and is pinned to a 2023 API version.

This package takes the opposite approach: the runtime is a hand port of
`stripe-node`, and the models are generated from Stripe's own OpenAPI
specification by a generator that lives in this repository. Bumping the API
version is a command, not a fork.

## Webhooks

Signature verification is static — it needs no client and no API key:

```dart
final event = StripeWebhooks.constructEvent(
  payload: request.rawBody,
  header: request.headers['stripe-signature']!,
  secret: endpointSecret,
);
```

Pass the **raw** request bytes, never a re-encoded or already-parsed body.
Verification uses a constant-time comparison, accepts any one of the signatures
present in the header (so secret rotation works), and rejects timestamps
outside a 300-second tolerance.

## Fidelity to stripe-node

This client reproduces `stripe-node` 19.3.1's observable behaviour, including
details that are easy to get subtly wrong:

- Retries on 409, on 5xx, and on a connection reset, with jittered exponential
  backoff capped at five seconds, honouring `Retry-After` up to 60 seconds, and
  respecting the server's `stripe-should-retry` header over all of it.
- An idempotency key is generated for every POST, so those retries are safe.
- Request bodies follow Stripe's bracket-notation form encoding exactly,
  including the way empty collections disappear from the wire entirely.

Conformance is enforced by golden tests whose fixtures were captured from the
real `stripe-node`, not written by hand.

## Scope

**Covered.** The v1 API: Checkout, Billing Portal, Customers, Subscriptions,
Prices, Products, Invoices, Promotion Codes, Coupons, Discounts, Events,
Customer Balance Transactions, Payment Intents, Charges, Refunds, Setup
Intents and Payment Methods — plus webhook verification and auto-pagination.

**Not covered.** The v2 API, Connect, Issuing, Terminal, Tax registrations,
file uploads, and Stripe's realtime/SSE surfaces. The generator's allowlist is
one file; widening it is a small change, so open an issue if you need a
resource that is missing.

## Relationship to stripe-node and to Stripe

This is an independent port, not an official Stripe product and not endorsed by
Stripe. See `THIRD_PARTY_NOTICES` for the licences of `stripe-node`, `qs` and
Stripe's OpenAPI specification, whose terms this package's derivation respects.
