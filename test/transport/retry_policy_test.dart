import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:stripe_client/src/transport/retry_policy.dart';
import 'package:test/test.dart';

http.Response _response(int statusCode, {Map<String, String>? headers}) =>
    http.Response('', statusCode, headers: headers ?? const {});

void main() {
  group('stripeShouldRetry', () {
    test('never retries once the retry budget is exhausted', () {
      expect(
        stripeShouldRetry(
          attempt: 2,
          maxNetworkRetries: 2,
          response: _response(500),
        ),
        isFalse,
      );
    });

    test('budget exhaustion wins even when stripe-should-retry says true', () {
      expect(
        stripeShouldRetry(
          attempt: 2,
          maxNetworkRetries: 2,
          response: _response(200, headers: {'stripe-should-retry': 'true'}),
        ),
        isFalse,
      );
    });

    test(
      'obeys stripe-should-retry: true on a 200, which would not '
      'otherwise be retried',
      () {
        expect(
          stripeShouldRetry(
            attempt: 0,
            maxNetworkRetries: 2,
            response: _response(200, headers: {'stripe-should-retry': 'true'}),
          ),
          isTrue,
        );
      },
    );

    test(
      'obeys stripe-should-retry: false on a 500, which would '
      'otherwise be retried',
      () {
        expect(
          stripeShouldRetry(
            attempt: 0,
            maxNetworkRetries: 2,
            response: _response(500, headers: {'stripe-should-retry': 'false'}),
          ),
          isFalse,
        );
      },
    );

    test('retries a 409 with no header', () {
      expect(
        stripeShouldRetry(
          attempt: 0,
          maxNetworkRetries: 2,
          response: _response(409),
        ),
        isTrue,
      );
    });

    test('retries a 5xx with no header', () {
      expect(
        stripeShouldRetry(
          attempt: 0,
          maxNetworkRetries: 2,
          response: _response(500),
        ),
        isTrue,
      );
    });

    test('does not retry a 400 with no header', () {
      expect(
        stripeShouldRetry(
          attempt: 0,
          maxNetworkRetries: 2,
          response: _response(400),
        ),
        isFalse,
      );
    });

    test('retries when there is no response at all, subject to budget', () {
      expect(
        stripeShouldRetry(attempt: 0, maxNetworkRetries: 2, response: null),
        isTrue,
      );
      expect(
        stripeShouldRetry(attempt: 2, maxNetworkRetries: 2, response: null),
        isFalse,
      );
    });
  });

  group('stripeRetryDelay', () {
    test('honours Retry-After capped at maxRetryAfterWait', () {
      final delay = stripeRetryDelay(
        attempt: 0,
        initialDelay: const Duration(milliseconds: 500),
        maxDelay: const Duration(seconds: 5),
        retryAfter: const Duration(seconds: 120),
        maxRetryAfterWait: const Duration(seconds: 60),
      );
      expect(delay, const Duration(seconds: 60));
    });

    test('honours Retry-After unchanged when under the cap', () {
      final delay = stripeRetryDelay(
        attempt: 0,
        initialDelay: const Duration(milliseconds: 500),
        maxDelay: const Duration(seconds: 5),
        retryAfter: const Duration(seconds: 10),
        maxRetryAfterWait: const Duration(seconds: 60),
      );
      expect(delay, const Duration(seconds: 10));
    });

    test(
      'without Retry-After, grows with attempt and stays capped at '
      'maxNetworkRetryDelay',
      () {
        // A fresh, identically-seeded Random for each call makes the first
        // (and only) jitter draw identical across calls, isolating the
        // exponential-backoff growth from the randomness applied on top of
        // it.
        Duration delayFor(int attempt) => stripeRetryDelay(
              attempt: attempt,
              initialDelay: const Duration(milliseconds: 500),
              maxDelay: const Duration(seconds: 5),
              maxRetryAfterWait: const Duration(seconds: 60),
              random: Random(1),
            );

        final first = delayFor(0);
        final second = delayFor(1);
        final third = delayFor(2);
        final farOut = delayFor(10);

        expect(second, greaterThan(first));
        expect(third, greaterThan(second));
        expect(farOut, lessThanOrEqualTo(const Duration(seconds: 5)));
      },
    );

    test('jitter produces bounded, non-identical delays across many draws', () {
      final random = Random(7);
      final delays = List<Duration>.generate(
        200,
        (_) => stripeRetryDelay(
          attempt: 3,
          initialDelay: const Duration(milliseconds: 500),
          maxDelay: const Duration(seconds: 5),
          maxRetryAfterWait: const Duration(seconds: 60),
          random: random,
        ),
      );

      // attempt 3 with a 500ms initial delay: 500ms * 2^3 = 4000ms, under
      // the 5s cap, so jitter alone determines the spread within [0.5, 1.0).
      const uncapped = Duration(milliseconds: 4000);
      for (final delay in delays) {
        expect(delay, greaterThanOrEqualTo(uncapped * 0.5));
        expect(delay, lessThanOrEqualTo(uncapped));
      }
      expect(delays.toSet().length, greaterThan(1));
    });
  });
}
