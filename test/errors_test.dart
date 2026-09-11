import 'dart:convert';
import 'dart:io';

import 'package:stripe_client/src/errors.dart';
import 'package:test/test.dart';

Map<String, Object?> _loadFixture() =>
    jsonDecode(File('test/fixtures/error_golden.json').readAsStringSync())
        as Map<String, Object?>;

Map<String, String> _headersOf(Map<String, Object?> input) =>
    (input['headers']! as Map<String, Object?>).cast<String, String>();

StripeError _buildFromCase(Map<String, Object?> testCase) {
  final input = testCase['input']! as Map<String, Object?>;
  return stripeErrorFromResponse(
    statusCode: input['statusCode']! as int,
    rawError: testCase['rawError'],
    headers: _headersOf(input),
    requestId: input['requestId'] as String?,
  );
}

void _expectMatchesGolden(StripeError error, Map<String, Object?> expected) {
  expect(error.runtimeType.toString(), expected['className']);
  expect(error.message, expected['message']);
  expect(error.code, expected['code']);
  expect(error.type, expected['type']);
  expect(error.statusCode, expected['statusCode']);
  expect(error.requestId, expected['requestId']);
  expect(error.param, expected['param']);
  expect(error.docUrl, expected['docUrl']);
  expect(error.detail, expected['detail']);
  expect(error.charge, expected['charge']);
  expect(error.declineCode, expected['declineCode']);
  expect(error.paymentIntent, expected['paymentIntent']);
  expect(error.paymentMethod, expected['paymentMethod']);
  expect(error.paymentMethodType, expected['paymentMethodType']);
  expect(error.setupIntent, expected['setupIntent']);
  expect(error.source, expected['source']);
  expect(error.userMessage, expected['userMessage']);
  expect(error.headers, expected['headers']);
}

void main() {
  final fixture = _loadFixture();
  final cases =
      (fixture['cases']! as List<Object?>).cast<Map<String, Object?>>();

  group('golden fixtures captured from stripe-node 19.3.1', () {
    for (final testCase in cases) {
      test(testCase['name']! as String, () {
        final error = _buildFromCase(testCase);
        _expectMatchesGolden(
          error,
          testCase['expected']! as Map<String, Object?>,
        );
      });
    }
  });

  group('status overrides type before the type switch ever runs', () {
    test(
      'a 429 response with a card_error body becomes a rate-limit error, '
      'not a card error, and the raw type string still survives',
      () {
        final error = stripeErrorFromResponse(
          statusCode: 429,
          rawError: {'type': 'card_error', 'message': 'looks like a card'},
          headers: const {},
        );
        expect(error, isA<StripeRateLimitError>());
        expect(error, isNot(isA<StripeCardError>()));
        expect(error.type, 'card_error');
      },
    );

    test(
      'a 401 response with a card_error body becomes an authentication '
      'error, not a card error',
      () {
        final error = stripeErrorFromResponse(
          statusCode: 401,
          rawError: {'type': 'card_error', 'message': 'looks like a card'},
          headers: const {},
        );
        expect(error, isA<StripeAuthenticationError>());
      },
    );

    test(
      'a 403 response with an invalid_request_error body becomes a '
      'permission error, not an invalid-request error',
      () {
        final error = stripeErrorFromResponse(
          statusCode: 403,
          rawError: {'type': 'invalid_request_error', 'message': 'nope'},
          headers: const {},
        );
        expect(error, isA<StripePermissionError>());
        expect(error, isNot(isA<StripeInvalidRequestError>()));
      },
    );

    test('a status outside 401/403/429 lets the type string dispatch', () {
      final error = stripeErrorFromResponse(
        statusCode: 400,
        rawError: {'type': 'rate_limit_error', 'message': 'too fast'},
        headers: const {},
      );
      expect(error, isA<StripeRateLimitError>());
    });
  });

  group('malformed or missing bodies', () {
    test('rawError null produces a usable StripeAPIError, not a crash', () {
      final error = stripeErrorFromResponse(
        statusCode: 500,
        rawError: null,
        headers: const {'content-type': 'application/json'},
        requestId: 'req_abc',
      );
      expect(error, isA<StripeAPIError>());
      expect(error.message, 'Invalid JSON received from the Stripe API');
      expect(error.requestId, 'req_abc');
      expect(error.statusCode, isNull);
      expect(error.headers, isNull);
    });

    test(
      'rawError null takes precedence over the status short-circuit too',
      () {
        final error = stripeErrorFromResponse(
          statusCode: 401,
          rawError: null,
          headers: const {},
        );
        expect(error, isA<StripeAPIError>());
        expect(error, isNot(isA<StripeAuthenticationError>()));
      },
    );

    test('an unrecognised rawError shape fails loudly instead of guessing', () {
      expect(
        () => stripeErrorFromResponse(
          statusCode: 400,
          rawError: 42,
          headers: const {},
        ),
        throwsArgumentError,
      );
    });
  });

  group('StripeConnectionError', () {
    test('is never built by stripeErrorFromResponse', () {
      final error = stripeErrorFromResponse(
        statusCode: 500,
        rawError: {'type': 'api_error', 'message': 'server error'},
        headers: const {},
      );
      expect(error, isNot(isA<StripeConnectionError>()));
    });

    test('carries the message and wraps the transport-level cause', () {
      final cause = Exception('socket closed');
      final error = StripeConnectionError(
        'An error occurred with our connection to Stripe.',
        cause: cause,
      );
      expect(
        error.message,
        'An error occurred with our connection to Stripe.',
      );
      expect(error.detail, same(cause));
      expect(error, isA<StripeError>());
    });
  });

  group('sealed hierarchy', () {
    test('every concrete subtype is reachable from an exhaustive switch', () {
      String describe(StripeError error) => switch (error) {
            StripeCardError() => 'card',
            StripeInvalidRequestError() => 'invalid_request',
            StripeAPIError() => 'api',
            StripeAuthenticationError() => 'authentication',
            StripePermissionError() => 'permission',
            StripeRateLimitError() => 'rate_limit',
            StripeConnectionError() => 'connection',
            StripeIdempotencyError() => 'idempotency',
            StripeInvalidGrantError() => 'invalid_grant',
            StripeSignatureVerificationError() => 'signature_verification',
            StripeUnknownError() => 'unknown',
          };

      expect(describe(const StripeCardError(message: 'x')), 'card');
      expect(describe(StripeConnectionError('x')), 'connection');
      expect(
        describe(
          const StripeSignatureVerificationError(
            message: 'x',
            header: null,
            payload: null,
          ),
        ),
        'signature_verification',
      );
    });
  });

  group('toString', () {
    test('produces a one-line "ClassName: message" summary', () {
      const error = StripeCardError(message: 'Your card was declined.');
      expect(error.toString(), 'StripeCardError: Your card was declined.');
    });
  });
}
