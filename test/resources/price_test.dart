import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stripe_client/src/resources/price.dart';
import 'package:stripe_client/src/transport/stripe_client.dart';
import 'package:test/test.dart';

void main() {
  group('PriceRecurring.fromJson', () {
    test('decodes interval and intervalCount', () {
      final recurring = PriceRecurring.fromJson({
        'interval': 'month',
        'interval_count': 1,
      });
      expect(recurring.interval, 'month');
      expect(recurring.intervalCount, 1);
    });

    test('toString summarises interval and intervalCount', () {
      const recurring = PriceRecurring(interval: 'year', intervalCount: 1);
      expect(
        recurring.toString(),
        'PriceRecurring(interval: year, intervalCount: 1)',
      );
    });
  });

  group('Price.fromJson', () {
    test('decodes a bare product id when unexpanded', () {
      final price = Price.fromJson({
        'id': 'price_123',
        'object': 'price',
        'unit_amount': 1999,
        'currency': 'usd',
        'product': 'prod_123',
        'recurring': {'interval': 'month', 'interval_count': 1},
      });

      expect(price.id, 'price_123');
      expect(price.unitAmount, 1999);
      expect(price.currency, 'usd');
      expect(price.product!.isExpanded, isFalse);
      expect(price.product!.id, 'prod_123');
      expect(price.recurring!.interval, 'month');
    });

    test('decodes an expanded product', () {
      final price = Price.fromJson({
        'id': 'price_123',
        'object': 'price',
        'product': {'id': 'prod_123', 'object': 'product', 'name': 'Plan'},
      });

      expect(price.product!.isExpanded, isTrue);
      expect(price.product!.value!.name, 'Plan');
    });

    test('leaves product, recurring and amounts null when absent', () {
      final price = Price.fromJson({'id': 'price_123', 'object': 'price'});

      expect(price.product, isNull);
      expect(price.recurring, isNull);
      expect(price.unitAmount, isNull);
      expect(price.currency, isNull);
    });

    test('throws when id is missing', () {
      expect(
        () => Price.fromJson(<String, Object?>{}),
        throwsA(isA<Object>()),
      );
    });

    test('toString summarises id, unitAmount and currency', () {
      const price = Price(id: 'price_123', unitAmount: 1999, currency: 'usd');
      expect(
        price.toString(),
        'Price(id: price_123, unitAmount: 1999, currency: usd)',
      );
    });
  });

  group('StripeClient.prices.retrieve', () {
    test('sends a GET to /v1/prices/{id}', () async {
      http.Request? captured;
      final client = StripeClient(
        apiKey: 'sk_test_123',
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode(
                {'id': 'price_123', 'object': 'price', 'unit_amount': 500}),
            200,
          );
        }),
      );

      final price = await client.prices.retrieve('price_123');

      expect(price.id, 'price_123');
      expect(price.unitAmount, 500);
      expect(captured!.method, 'GET');
      expect(captured!.url.path, '/v1/prices/price_123');
    });
  });
}
