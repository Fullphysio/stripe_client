import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stripe_client/src/resources/billing_portal_session.dart';
import 'package:stripe_client/src/transport/stripe_client.dart';
import 'package:test/test.dart';

void main() {
  group('BillingPortalSession.fromJson', () {
    test('decodes id and url from a realistic payload', () {
      final session = BillingPortalSession.fromJson({
        'id': 'bps_1MvL2x',
        'object': 'billing_portal.session',
        'customer': 'cus_123',
        'url': 'https://billing.stripe.com/session/abc123',
        'return_url': 'https://example.com/account',
        'created': 1731600000,
        'livemode': false,
      });

      expect(session.id, 'bps_1MvL2x');
      expect(session.url, 'https://billing.stripe.com/session/abc123');
    });

    test('leaves url null when the payload omits it', () {
      final session = BillingPortalSession.fromJson({
        'id': 'bps_1MvL2x',
        'object': 'billing_portal.session',
      });

      expect(session.id, 'bps_1MvL2x');
      expect(session.url, isNull);
    });

    test('throws when id is missing', () {
      expect(
        () => BillingPortalSession.fromJson(<String, Object?>{}),
        throwsA(isA<Object>()),
      );
    });

    test('toString summarises id and url', () {
      const session = BillingPortalSession(
        id: 'bps_1MvL2x',
        url: 'https://billing.stripe.com/session/abc123',
      );

      expect(
        session.toString(),
        'BillingPortalSession(id: bps_1MvL2x, '
        'url: https://billing.stripe.com/session/abc123)',
      );
    });
  });

  group('BillingPortalSessionCreateParams.toJson', () {
    test('encodes customer and return_url exactly', () {
      const params = BillingPortalSessionCreateParams(
        customer: 'cus_123',
        returnUrl: 'https://example.com/account',
      );

      expect(params.toJson(), {
        'customer': 'cus_123',
        'return_url': 'https://example.com/account',
      });
    });

    test('omits locale from the map when not provided', () {
      const params = BillingPortalSessionCreateParams(
        customer: 'cus_123',
        returnUrl: 'https://example.com/account',
      );

      expect(params.toJson(), isNot(contains('locale')));
    });

    test('encodes locale when provided', () {
      const params = BillingPortalSessionCreateParams(
        customer: 'cus_123',
        returnUrl: 'https://example.com/account',
        locale: 'fr',
      );

      expect(params.toJson(), {
        'customer': 'cus_123',
        'return_url': 'https://example.com/account',
        'locale': 'fr',
      });
    });

    test('toString summarises customer and returnUrl', () {
      const params = BillingPortalSessionCreateParams(
        customer: 'cus_123',
        returnUrl: 'https://example.com/account',
      );

      expect(
        params.toString(),
        'BillingPortalSessionCreateParams(customer: cus_123, '
        'returnUrl: https://example.com/account)',
      );
    });
  });

  group('StripeClient.billingPortal.sessions.create', () {
    test('returns a populated BillingPortalSession from a mocked response',
        () async {
      http.Request? captured;
      final client = StripeClient(
        apiKey: 'sk_test_123',
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'id': 'bps_1MvL2x',
              'object': 'billing_portal.session',
              'url': 'https://billing.stripe.com/session/abc123',
            }),
            200,
          );
        }),
      );

      final session = await client.billingPortal.sessions.create(
        const BillingPortalSessionCreateParams(
          customer: 'cus_123',
          returnUrl: 'https://example.com/account',
        ),
      );

      expect(session.id, 'bps_1MvL2x');
      expect(session.url, 'https://billing.stripe.com/session/abc123');
      expect(captured!.method, 'POST');
      expect(captured!.url.path, '/v1/billing_portal/sessions');
      expect(
        captured!.body,
        'customer=cus_123&return_url=https%3A%2F%2Fexample.com%2Faccount',
      );
    });
  });
}
