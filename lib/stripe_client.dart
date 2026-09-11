/// A pure Dart client for the Stripe API.
///
/// Typed resources, webhook signature verification, automatic retries and
/// idempotency keys, from Dart servers, CLIs and Flutter apps alike. No
/// Flutter dependency.
///
/// The runtime behaviour is a deliberate port of the official Node client,
/// `stripe-node` 19.3.1 — retry policy, backoff, idempotency-key generation,
/// webhook signature verification, pagination cursors and error mapping all
/// follow that implementation. Typed models are generated from Stripe's
/// OpenAPI specification at revision v2111.
library;

// Exports are added here as each module lands. Keep this list selective:
// internal plumbing (form encoding, crypto helpers, header utilities) stays
// unexported.
