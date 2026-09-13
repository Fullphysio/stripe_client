import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stripe_client/src/resources/product.dart';
import 'package:stripe_client/src/transport/stripe_client.dart';
import 'package:test/test.dart';

void main() {
  group('Product.fromJson', () {
    test('decodes id and name from a realistic payload', () {
      final product = Product.fromJson({
        'id': 'prod_123',
        'object': 'product',
        'name': 'Premium plan',
        'active': true,
      });

      expect(product.id, 'prod_123');
      expect(product.name, 'Premium plan');
    });

    test('leaves name null when the payload omits it', () {
      final product = Product.fromJson({'id': 'prod_123', 'object': 'product'});

      expect(product.id, 'prod_123');
      expect(product.name, isNull);
    });

    test('throws when id is missing', () {
      expect(
        () => Product.fromJson(<String, Object?>{}),
        throwsA(isA<Object>()),
      );
    });

    test('toString summarises id and name', () {
      const product = Product(id: 'prod_123', name: 'Premium plan');
      expect(product.toString(), 'Product(id: prod_123, name: Premium plan)');
    });
  });

  group('StripeClient.products.retrieve', () {
    test('sends a GET to /v1/products/{id}', () async {
      http.Request? captured;
      final client = StripeClient(
        apiKey: 'sk_test_123',
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({'id': 'prod_123', 'object': 'product', 'name': 'Plan'}),
            200,
          );
        }),
      );

      final product = await client.products.retrieve('prod_123');

      expect(product.id, 'prod_123');
      expect(product.name, 'Plan');
      expect(captured!.method, 'GET');
      expect(captured!.url.path, '/v1/products/prod_123');
    });
  });
}
