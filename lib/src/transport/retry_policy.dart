import 'dart:math';

import 'package:http/http.dart' as http;

/// Decides whether a Stripe request attempt should be retried.
///
/// Reproduces `stripe-node` 19.3.1's retry decision, checked in this strict
/// precedence order:
///
/// 1. [attempt] has already reached [maxNetworkRetries] — never retry,
///    regardless of anything else below.
/// 2. [response] carries a `stripe-should-retry` header — obey it exactly,
///    whether it says `true` or `false`, regardless of [response]'s status
///    code. Stripe sends this header to override the default policy for a
///    specific response.
/// 3. There is no [response] at all — a connection reset, DNS failure, or
///    timeout that never produced one — so retry, since the request may
///    never have reached Stripe.
/// 4. Otherwise, retry only on a 409 (a concurrent-update conflict) or a
///    5xx (a failure on Stripe's side); every other status is left alone.
bool stripeShouldRetry({
  required int attempt,
  required int maxNetworkRetries,
  http.Response? response,
}) {
  if (attempt >= maxNetworkRetries) {
    return false;
  }
  final shouldRetryHeader = response?.headers['stripe-should-retry'];
  if (shouldRetryHeader == 'true') {
    return true;
  }
  if (shouldRetryHeader == 'false') {
    return false;
  }
  if (response == null) {
    return true;
  }
  return response.statusCode == 409 || response.statusCode >= 500;
}

/// Computes how long to wait before the retry numbered [attempt].
///
/// When [retryAfter] is given — parsed from a response's `Retry-After`
/// header — it is honoured instead of the exponential backoff described
/// below, capped at [maxRetryAfterWait].
///
/// Otherwise, the delay is [initialDelay] doubled once per [attempt] and
/// capped at [maxDelay], then scaled by a random factor in the range
/// `[0.5, 1.0)` — full jitter — so that several clients retrying the same
/// failure don't all wake up and retry in lockstep. [random] is an injection
/// seam for deterministic tests; when omitted, a fresh, unseeded [Random] is
/// used.
Duration stripeRetryDelay({
  required int attempt,
  required Duration initialDelay,
  required Duration maxDelay,
  Duration? retryAfter,
  required Duration maxRetryAfterWait,
  Random? random,
}) {
  if (retryAfter != null) {
    return retryAfter > maxRetryAfterWait ? maxRetryAfterWait : retryAfter;
  }
  final exponential = initialDelay * (1 << attempt);
  final capped = exponential > maxDelay ? maxDelay : exponential;
  final jitter = (random ?? Random()).nextDouble() * 0.5 + 0.5;
  return capped * jitter;
}
