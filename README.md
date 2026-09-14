# stripe_client

A pure Dart client for the Stripe API. Runs on Dart servers, CLIs and Flutter
apps — there is no Flutter dependency, and no build step for you.

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
`stripe-node`, and the models are written against Stripe's own OpenAPI
specification, vendored in this repository and pinned by digest. Bumping the
API version is a diff against that spec, not a fork of a closed generator.

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

This is an early release, and the operations below are the whole of it:

| Namespace | Operations |
|---|---|
| `checkout.sessions` | `create` |
| `billingPortal.sessions` | `create` |
| `customers` | `retrieve`, `update`, `createBalanceTransaction` |
| `subscriptions` | `retrieve`, `list` |
| `promotionCodes` | `create`, `retrieve`, `list` |
| `invoices` | `retrieve` |
| `prices` | `retrieve` |
| `products` | `retrieve` |

Plus webhook signature verification, and decoding for the objects those
operations and webhook payloads return — including `Coupon`, `Discount`,
`Event`, `Plan`, `InvoiceLineItem` and `SubscriptionItem`.

**Not here yet.** Pagination past one page: `list` takes a `limit` but no
`starting_after` cursor, so it cannot walk beyond 100 objects. Writes other
than the ones above (no `subscriptions.update`, no `invoices.list`). Payment
Intents, Charges, Refunds, Setup Intents and Payment Methods as resources —
they appear only in `StripeCardError`'s fields today.

**Out of scope.** The v2 API, Connect, Issuing, Terminal, Tax registrations,
file uploads, and Stripe's realtime/SSE surfaces.

Adding a missing operation is a small, mechanical change against the vendored
spec — open an issue if you need one.

## Relationship to stripe-node and to Stripe

This is an independent port, not an official Stripe product and not endorsed by
Stripe. See `THIRD_PARTY_NOTICES` for the licences of `stripe-node`, `qs` and
Stripe's OpenAPI specification, whose terms this package's derivation respects.
