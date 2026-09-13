import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stripe_client/src/errors.dart';
import 'package:stripe_client/src/transport/stripe_client.dart';
import 'package:test/test.dart';

void main() {
  group('request headers', () {
    test('a bodyless GET sends Content-Length: 0 and no Idempotency-Key',
        () async {
      http.Request? captured;
      final client = StripeClient(
        apiKey: 'sk_test_123',
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({'ok': true}), 200);
        }),
      );

      await client.request(
        method: 'GET',
        path: '/v1/billing_portal/sessions',
      );

      expect(captured!.headers['Content-Length'], '0');
      expect(captured!.headers.containsKey('Idempotency-Key'), isFalse);
      expect(captured!.headers['Authorization'], 'Bearer sk_test_123');
      expect(
        captured!.headers['Content-Type'],
        'application/x-www-form-urlencoded',
      );
    });

    test('a POST sends an Idempotency-Key and the form-encoded body', () async {
      http.Request? captured;
      final client = StripeClient(
        apiKey: 'sk_test_123',
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({'id': 'bps_123'}), 200);
        }),
      );

      await client.request(
        method: 'POST',
        path: '/v1/billing_portal/sessions',
        params: const {'customer': 'cus_123'},
      );

      expect(captured!.headers['Idempotency-Key'], isNotEmpty);
      expect(captured!.body, 'customer=cus_123');
      expect(
        captured!.headers['Content-Type'],
        'application/x-www-form-urlencoded',
      );
    });

    test('a caller-supplied idempotencyKey overrides auto-generation',
        () async {
      http.Request? captured;
      final client = StripeClient(
        apiKey: 'sk_test_123',
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({'id': 'bps_123'}), 200);
        }),
      );

      await client.request(
        method: 'POST',
        path: '/v1/billing_portal/sessions',
        params: const {'customer': 'cus_123'},
        idempotencyKey: 'my-custom-key',
      );

      expect(captured!.headers['Idempotency-Key'], 'my-custom-key');
    });

    test('Stripe-Version is present and correct on every request', () async {
      final versions = <String?>[];
      final client = StripeClient(
        apiKey: 'sk_test_123',
        httpClient: MockClient((request) async {
          versions.add(request.headers['Stripe-Version']);
          return http.Response(jsonEncode({'id': 'bps_123'}), 200);
        }),
      );

      await client.request(
        method: 'GET',
        path: '/v1/billing_portal/sessions',
      );
      await client.request(
        method: 'POST',
        path: '/v1/billing_portal/sessions',
        params: const {'customer': 'cus_123'},
      );

      expect(versions, everyElement('2025-11-17.clover'));
    });
  });

  group('retries', () {
    test(
      'a 500, 500, 200 sequence sends exactly 3 requests and returns the '
      'successful result',
      () async {
        var callCount = 0;
        final client = StripeClient(
          apiKey: 'sk_test_123',
          initialNetworkRetryDelay: Duration.zero,
          httpClient: MockClient((request) async {
            callCount++;
            if (callCount < 3) {
              return http.Response('server error', 500);
            }
            return http.Response(jsonEncode({'id': 'bps_123'}), 200);
          }),
        );

        final result = await client.request(
          method: 'GET',
          path: '/v1/billing_portal/sessions',
        );

        expect(callCount, 3);
        expect(result, {'id': 'bps_123'});
      },
    );

    test('the same Idempotency-Key is reused across every retry of a call',
        () async {
      final idempotencyKeys = <String?>[];
      var callCount = 0;
      final client = StripeClient(
        apiKey: 'sk_test_123',
        initialNetworkRetryDelay: Duration.zero,
        httpClient: MockClient((request) async {
          callCount++;
          idempotencyKeys.add(request.headers['Idempotency-Key']);
          if (callCount < 3) {
            return http.Response('server error', 500);
          }
          return http.Response(jsonEncode({'id': 'bps_123'}), 200);
        }),
      );

      await client.request(
        method: 'POST',
        path: '/v1/billing_portal/sessions',
        params: const {'customer': 'cus_123'},
      );

      expect(callCount, 3);
      expect(idempotencyKeys.toSet(), hasLength(1));
      expect(idempotencyKeys.first, isNotEmpty);
    });

    test(
        'stripe-should-retry: false on a 500 sends exactly 1 request and '
        'throws', () async {
      var callCount = 0;
      final client = StripeClient(
        apiKey: 'sk_test_123',
        initialNetworkRetryDelay: Duration.zero,
        httpClient: MockClient((request) async {
          callCount++;
          return http.Response(
            'server error',
            500,
            headers: {'stripe-should-retry': 'false'},
          );
        }),
      );

      await expectLater(
        client.request(method: 'GET', path: '/v1/billing_portal/sessions'),
        throwsA(isA<StripeError>()),
      );
      expect(callCount, 1);
    });

    test('honours a Retry-After header when present', () async {
      var callCount = 0;
      final client = StripeClient(
        apiKey: 'sk_test_123',
        httpClient: MockClient((request) async {
          callCount++;
          if (callCount == 1) {
            return http.Response(
              'unavailable',
              503,
              headers: {'retry-after': '0'},
            );
          }
          return http.Response(jsonEncode({'id': 'bps_123'}), 200);
        }),
      );

      final result = await client.request(
        method: 'GET',
        path: '/v1/billing_portal/sessions',
      );

      expect(callCount, 2);
      expect(result, {'id': 'bps_123'});
    });
  });

  group('connection errors', () {
    test('a connection error is retried and can still succeed', () async {
      var callCount = 0;
      final client = StripeClient(
        apiKey: 'sk_test_123',
        initialNetworkRetryDelay: Duration.zero,
        httpClient: MockClient((request) async {
          callCount++;
          if (callCount < 2) {
            throw Exception('socket closed');
          }
          return http.Response(jsonEncode({'id': 'bps_123'}), 200);
        }),
      );

      final result = await client.request(
        method: 'GET',
        path: '/v1/billing_portal/sessions',
      );

      expect(callCount, 2);
      expect(result, {'id': 'bps_123'});
    });

    test(
      'a connection error exhausts the retry budget and throws '
      'StripeConnectionError',
      () async {
        var callCount = 0;
        final client = StripeClient(
          apiKey: 'sk_test_123',
          maxNetworkRetries: 0,
          initialNetworkRetryDelay: Duration.zero,
          httpClient: MockClient((request) async {
            callCount++;
            throw Exception('socket closed');
          }),
        );

        await expectLater(
          client.request(method: 'GET', path: '/v1/billing_portal/sessions'),
          throwsA(isA<StripeConnectionError>()),
        );
        expect(callCount, 1);
      },
    );
  });

  group('error mapping', () {
    test(
      'a non-2xx response with a Stripe-shaped body throws the matching '
      'StripeError subtype',
      () async {
        final client = StripeClient(
          apiKey: 'sk_test_123',
          httpClient: MockClient((request) async {
            return http.Response(
              jsonEncode({
                'error': {
                  'type': 'invalid_request_error',
                  'message': 'Missing required param: customer.',
                  'param': 'customer',
                },
              }),
              400,
              headers: {'request-id': 'req_123'},
            );
          }),
        );

        await expectLater(
          client.request(method: 'GET', path: '/v1/billing_portal/sessions'),
          throwsA(
            isA<StripeInvalidRequestError>()
                .having((e) => e.param, 'param', 'customer')
                .having((e) => e.requestId, 'requestId', 'req_123'),
          ),
        );
      },
    );

    test('a non-2xx response with an empty body still throws a usable error',
        () async {
      final client = StripeClient(
        apiKey: 'sk_test_123',
        maxNetworkRetries: 0,
        httpClient: MockClient((request) async {
          return http.Response('', 500);
        }),
      );

      await expectLater(
        client.request(method: 'GET', path: '/v1/billing_portal/sessions'),
        throwsA(
          isA<StripeAPIError>().having(
            (e) => e.message,
            'message',
            'Invalid JSON received from the Stripe API',
          ),
        ),
      );
    });

    test(
      'a non-2xx response with a non-JSON body still throws a usable error',
      () async {
        final client = StripeClient(
          apiKey: 'sk_test_123',
          maxNetworkRetries: 0,
          httpClient: MockClient((request) async {
            return http.Response('<html>Bad Gateway</html>', 502);
          }),
        );

        await expectLater(
          client.request(method: 'GET', path: '/v1/billing_portal/sessions'),
          throwsA(
            isA<StripeAPIError>().having(
              (e) => e.message,
              'message',
              'Invalid JSON received from the Stripe API',
            ),
          ),
        );
      },
    );
  });

  group('close', () {
    test('closes an http.Client it created itself', () {
      final client = StripeClient(apiKey: 'sk_test_123');
      expect(client.close, returnsNormally);
    });

    test('does not close a caller-supplied http.Client', () {
      final tracking = _TrackingClient();
      final client = StripeClient(apiKey: 'sk_test_123', httpClient: tracking);

      client.close();

      expect(tracking.closed, isFalse);
    });
  });
}

class _TrackingClient extends http.BaseClient {
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(Stream.value(utf8.encode('{}')), 200);
  }

  @override
  void close() {
    closed = true;
    super.close();
  }
}
