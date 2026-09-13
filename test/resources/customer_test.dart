import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stripe_client/src/core/expand_params.dart';
import 'package:stripe_client/src/resources/customer.dart';
import 'package:stripe_client/src/transport/stripe_client.dart';
import 'package:test/test.dart';

void main() {
  group('Customer.fromJson', () {
    test('decodes a realistic payload', () {
      final customer = Customer.fromJson({
        'id': 'cus_123',
        'object': 'customer',
        'email': 'a@b.com',
        'name': 'Ada Lovelace',
        'metadata': {'plan': 'gold'},
        'balance': -500,
        'currency': 'usd',
      });

      expect(customer.id, 'cus_123');
      expect(customer.email, 'a@b.com');
      expect(customer.name, 'Ada Lovelace');
      expect(customer.metadata, {'plan': 'gold'});
      expect(customer.balance, -500);
      expect(customer.currency, 'usd');
      expect(customer.deleted, isNull);
    });

    test('decodes a deleted customer shape', () {
      final customer = Customer.fromJson({
        'id': 'cus_123',
        'object': 'customer',
        'deleted': true,
      });

      expect(customer.deleted, isTrue);
    });

    test('defaults metadata to an empty map when absent', () {
      final customer =
          Customer.fromJson({'id': 'cus_123', 'object': 'customer'});
      expect(customer.metadata, isEmpty);
    });

    test('throws when id is missing', () {
      expect(
        () => Customer.fromJson(<String, Object?>{}),
        throwsA(isA<Object>()),
      );
    });

    test('toString summarises id, email and name', () {
      const customer = Customer(id: 'cus_123', email: 'a@b.com', name: 'Ada');
      expect(
        customer.toString(),
        'Customer(id: cus_123, email: a@b.com, name: Ada)',
      );
    });
  });

  group('CustomerUpdateParams.toJson', () {
    test('encodes every field when given', () {
      const params = CustomerUpdateParams(
        email: 'a@b.com',
        name: 'Ada',
        metadata: {'plan': 'gold'},
      );

      expect(params.toJson(), {
        'email': 'a@b.com',
        'name': 'Ada',
        'metadata': {'plan': 'gold'},
      });
    });

    test('omits every field when none is given', () {
      const params = CustomerUpdateParams();
      expect(params.toJson(), isEmpty);
    });

    test('toString summarises email and name', () {
      const params = CustomerUpdateParams(email: 'a@b.com', name: 'Ada');
      expect(
        params.toString(),
        'CustomerUpdateParams(email: a@b.com, name: Ada)',
      );
    });
  });

  group('CustomerCreateBalanceTransactionParams.toJson', () {
    test('encodes amount and currency, omitting optional fields', () {
      const params =
          CustomerCreateBalanceTransactionParams(amount: -500, currency: 'usd');
      expect(params.toJson(), {'amount': -500, 'currency': 'usd'});
    });

    test('encodes description and metadata when given', () {
      const params = CustomerCreateBalanceTransactionParams(
        amount: -500,
        currency: 'usd',
        description: 'Goodwill credit',
        metadata: {'reason': 'support'},
      );

      expect(params.toJson(), {
        'amount': -500,
        'currency': 'usd',
        'description': 'Goodwill credit',
        'metadata': {'reason': 'support'},
      });
    });

    test('toString summarises amount and currency', () {
      const params =
          CustomerCreateBalanceTransactionParams(amount: -500, currency: 'usd');
      expect(
        params.toString(),
        'CustomerCreateBalanceTransactionParams(amount: -500, currency: usd)',
      );
    });
  });

  group('CustomerBalanceTransaction.fromJson', () {
    test('decodes a realistic payload', () {
      final transaction = CustomerBalanceTransaction.fromJson({
        'id': 'cbtxn_123',
        'object': 'customer_balance_transaction',
        'amount': -500,
        'currency': 'usd',
        'description': 'Goodwill credit',
        'ending_balance': -500,
        'created': 1731600000,
      });

      expect(transaction.id, 'cbtxn_123');
      expect(transaction.amount, -500);
      expect(transaction.currency, 'usd');
      expect(transaction.description, 'Goodwill credit');
      expect(transaction.endingBalance, -500);
      expect(transaction.created, isNotNull);
    });

    test('throws when id is missing', () {
      expect(
        () => CustomerBalanceTransaction.fromJson(<String, Object?>{}),
        throwsA(isA<Object>()),
      );
    });

    test('toString summarises id, amount and endingBalance', () {
      const transaction = CustomerBalanceTransaction(
          id: 'cbtxn_123', amount: -500, endingBalance: -500);
      expect(
        transaction.toString(),
        'CustomerBalanceTransaction(id: cbtxn_123, amount: -500, '
        'endingBalance: -500)',
      );
    });
  });

  group('StripeClient.customers', () {
    test('retrieve sends a GET to /v1/customers/{id}', () async {
      http.Request? captured;
      final client = StripeClient(
        apiKey: 'sk_test_123',
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({'id': 'cus_123', 'object': 'customer'}),
            200,
          );
        }),
      );

      final customer =
          await client.customers.retrieve('cus_123', const ExpandParams());

      expect(customer.id, 'cus_123');
      expect(captured!.method, 'GET');
      expect(captured!.url.path, '/v1/customers/cus_123');
    });

    test('update sends a POST with the form-encoded body', () async {
      http.Request? captured;
      final client = StripeClient(
        apiKey: 'sk_test_123',
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({'id': 'cus_123', 'object': 'customer', 'name': 'Ada'}),
            200,
          );
        }),
      );

      final customer = await client.customers.update(
        'cus_123',
        const CustomerUpdateParams(name: 'Ada'),
      );

      expect(customer.name, 'Ada');
      expect(captured!.method, 'POST');
      expect(captured!.url.path, '/v1/customers/cus_123');
      expect(captured!.body, 'name=Ada');
    });

    test(
      'createBalanceTransaction sends a POST to '
      '/v1/customers/{id}/balance_transactions',
      () async {
        http.Request? captured;
        final client = StripeClient(
          apiKey: 'sk_test_123',
          httpClient: MockClient((request) async {
            captured = request;
            return http.Response(
              jsonEncode({
                'id': 'cbtxn_123',
                'object': 'customer_balance_transaction',
                'amount': -500,
              }),
              200,
            );
          }),
        );

        final transaction = await client.customers.createBalanceTransaction(
          'cus_123',
          const CustomerCreateBalanceTransactionParams(
              amount: -500, currency: 'usd'),
        );

        expect(transaction.id, 'cbtxn_123');
        expect(captured!.method, 'POST');
        expect(
            captured!.url.path, '/v1/customers/cus_123/balance_transactions');
        expect(captured!.body, 'amount=-500&currency=usd');
      },
    );
  });
}
