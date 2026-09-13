import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stripe_client/src/core/expand_params.dart';
import 'package:stripe_client/src/core/stripe_list.dart';
import 'package:stripe_client/src/resources/subscription.dart';
import 'package:stripe_client/src/transport/stripe_client.dart';
import 'package:test/test.dart';

void main() {
  group('SubscriptionItem.fromJson', () {
    test('decodes both price and plan when the payload carries both', () {
      final item = SubscriptionItem.fromJson({
        'id': 'si_123',
        'object': 'subscription_item',
        'quantity': 2,
        'current_period_start': 1731000000,
        'current_period_end': 1733600000,
        'price': {
          'id': 'price_123',
          'object': 'price',
          'unit_amount': 999,
        },
        'plan': {
          'id': 'plan_123',
          'object': 'plan',
          'amount': 999,
          'product': 'prod_123',
        },
      });

      expect(item.id, 'si_123');
      expect(item.quantity, 2);
      expect(item.price!.id, 'price_123');
      expect(item.plan!.id, 'plan_123');
      expect(item.plan!.product!.id, 'prod_123');
      expect(
        item.currentPeriodStart,
        DateTime.fromMillisecondsSinceEpoch(1731000000000, isUtc: true),
      );
      expect(
        item.currentPeriodEnd,
        DateTime.fromMillisecondsSinceEpoch(1733600000000, isUtc: true),
      );
    });

    test('decodes a bare discount id on the item', () {
      final item = SubscriptionItem.fromJson({
        'id': 'si_123',
        'object': 'subscription_item',
        'discounts': ['di_123'],
      });

      expect(item.discounts, hasLength(1));
      expect(item.discounts.first.isExpanded, isFalse);
      expect(item.discounts.first.id, 'di_123');
    });

    test('decodes an expanded discount on the item', () {
      final item = SubscriptionItem.fromJson({
        'id': 'si_123',
        'object': 'subscription_item',
        'discounts': [
          {'id': 'di_123', 'object': 'discount'},
        ],
      });

      expect(item.discounts.first.isExpanded, isTrue);
      expect(item.discounts.first.id, 'di_123');
    });

    test('leaves price, plan and period fields null when absent', () {
      final item = SubscriptionItem.fromJson(
          {'id': 'si_123', 'object': 'subscription_item'});

      expect(item.price, isNull);
      expect(item.plan, isNull);
      expect(item.currentPeriodStart, isNull);
      expect(item.currentPeriodEnd, isNull);
      expect(item.discounts, isEmpty);
    });

    test('throws when id is missing', () {
      expect(
        () => SubscriptionItem.fromJson(<String, Object?>{}),
        throwsA(isA<Object>()),
      );
    });

    test('toString summarises id, quantity and currentPeriodEnd', () {
      const item = SubscriptionItem(id: 'si_123', quantity: 2);
      expect(
        item.toString(),
        'SubscriptionItem(id: si_123, quantity: 2, currentPeriodEnd: null)',
      );
    });
  });

  group('Subscription.fromJson', () {
    test(
      'reads currentPeriodStart/currentPeriodEnd from items.data[0] when '
      'the subscription itself has no such top-level fields',
      () {
        final subscription = Subscription.fromJson({
          'id': 'sub_123',
          'object': 'subscription',
          'status': 'active',
          'items': {
            'object': 'list',
            'has_more': false,
            'url': '/v1/subscription_items',
            'data': [
              {
                'id': 'si_123',
                'object': 'subscription_item',
                'current_period_start': 1731000000,
                'current_period_end': 1733600000,
              },
            ],
          },
        });

        expect(subscription.id, 'sub_123');
        expect(subscription.status, 'active');
        expect(
          subscription.currentPeriodStart,
          DateTime.fromMillisecondsSinceEpoch(1731000000000, isUtc: true),
        );
        expect(
          subscription.currentPeriodEnd,
          DateTime.fromMillisecondsSinceEpoch(1733600000000, isUtc: true),
        );
      },
    );

    test('currentPeriodStart/currentPeriodEnd are null when items is empty',
        () {
      final subscription = Subscription.fromJson({
        'id': 'sub_123',
        'object': 'subscription',
        'items': {
          'object': 'list',
          'has_more': false,
          'url': '/v1/subscription_items',
          'data': <Object?>[],
        },
      });

      expect(subscription.currentPeriodStart, isNull);
      expect(subscription.currentPeriodEnd, isNull);
    });

    test('decodes a bare latest_invoice id when unexpanded', () {
      final subscription = Subscription.fromJson({
        'id': 'sub_123',
        'object': 'subscription',
        'latest_invoice': 'in_123',
      });

      expect(subscription.latestInvoice!.isExpanded, isFalse);
      expect(subscription.latestInvoice!.id, 'in_123');
    });

    test('decodes an expanded latest_invoice object', () {
      final subscription = Subscription.fromJson({
        'id': 'sub_123',
        'object': 'subscription',
        'latest_invoice': {
          'id': 'in_123',
          'object': 'invoice',
          'status': 'paid',
        },
      });

      expect(subscription.latestInvoice!.isExpanded, isTrue);
      expect(subscription.latestInvoice!.value!.status, 'paid');
    });

    test('decodes a bare customer id when unexpanded', () {
      final subscription = Subscription.fromJson({
        'id': 'sub_123',
        'object': 'subscription',
        'customer': 'cus_123',
      });

      expect(subscription.customer!.isExpanded, isFalse);
      expect(subscription.customer!.id, 'cus_123');
    });

    test('decodes an expanded customer', () {
      final subscription = Subscription.fromJson({
        'id': 'sub_123',
        'object': 'subscription',
        'customer': {'id': 'cus_123', 'object': 'customer', 'email': 'a@b.com'},
      });

      expect(subscription.customer!.isExpanded, isTrue);
      expect(subscription.customer!.value!.email, 'a@b.com');
    });

    test('decodes an expanded discount in the subscription discounts list', () {
      final subscription = Subscription.fromJson({
        'id': 'sub_123',
        'object': 'subscription',
        'discounts': [
          {'id': 'di_123', 'object': 'discount'},
        ],
      });

      expect(subscription.discounts.first.isExpanded, isTrue);
      expect(subscription.discounts.first.id, 'di_123');
    });

    test('decodes discounts, timestamps and metadata', () {
      final subscription = Subscription.fromJson({
        'id': 'sub_123',
        'object': 'subscription',
        'discounts': ['di_123'],
        'currency': 'usd',
        'created': 1731000000,
        'start_date': 1731000000,
        'ended_at': 1733600000,
        'canceled_at': 1733600000,
        'cancel_at': 1733600000,
        'cancel_at_period_end': true,
        'trial_start': 1731000000,
        'trial_end': 1732000000,
        'trial_period_days': 14,
        'metadata': {'plan': 'gold'},
      });

      expect(subscription.discounts, hasLength(1));
      expect(subscription.currency, 'usd');
      expect(subscription.created, isNotNull);
      expect(subscription.startDate, isNotNull);
      expect(subscription.endedAt, isNotNull);
      expect(subscription.canceledAt, isNotNull);
      expect(subscription.cancelAt, isNotNull);
      expect(subscription.cancelAtPeriodEnd, isTrue);
      expect(subscription.trialStart, isNotNull);
      expect(subscription.trialEnd, isNotNull);
      expect(subscription.trialPeriodDays, 14);
      expect(subscription.metadata, {'plan': 'gold'});
    });

    test('leaves customer and latestInvoice null when absent', () {
      final subscription =
          Subscription.fromJson({'id': 'sub_123', 'object': 'subscription'});

      expect(subscription.customer, isNull);
      expect(subscription.latestInvoice, isNull);
      expect(subscription.items.data, isEmpty);
      expect(subscription.metadata, isEmpty);
    });

    test('throws when id is missing', () {
      expect(
        () => Subscription.fromJson(<String, Object?>{}),
        throwsA(isA<Object>()),
      );
    });

    test('toString summarises id and status', () {
      const subscription = Subscription(
          id: 'sub_123', status: 'active', items: StripeList(hasMore: false));
      expect(
          subscription.toString(), 'Subscription(id: sub_123, status: active)');
    });
  });

  group('SubscriptionListParams.toJson', () {
    test('omits every field when none is given', () {
      const params = SubscriptionListParams();
      expect(params.toJson(), isEmpty);
    });

    test('encodes every field when given', () {
      const params = SubscriptionListParams(
        customer: 'cus_123',
        status: 'active',
        limit: 5,
        expand: ['data.latest_invoice'],
      );

      expect(params.toJson(), {
        'customer': 'cus_123',
        'status': 'active',
        'limit': 5,
        'expand': ['data.latest_invoice'],
      });
    });

    test('toString summarises customer and status', () {
      const params =
          SubscriptionListParams(customer: 'cus_123', status: 'active');
      expect(
        params.toString(),
        'SubscriptionListParams(customer: cus_123, status: active)',
      );
    });
  });

  group('StripeClient.subscriptions', () {
    test('retrieve sends a GET to /v1/subscriptions/{id}', () async {
      http.Request? captured;
      final client = StripeClient(
        apiKey: 'sk_test_123',
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({'id': 'sub_123', 'object': 'subscription'}),
            200,
          );
        }),
      );

      final subscription = await client.subscriptions
          .retrieve('sub_123', const ExpandParams(expand: ['latest_invoice']));

      expect(subscription.id, 'sub_123');
      expect(captured!.method, 'GET');
      expect(captured!.url.path, '/v1/subscriptions/sub_123');
      expect(captured!.url.query, 'expand%5B0%5D=latest_invoice');
    });

    test('list sends a GET to /v1/subscriptions and returns a StripeList',
        () async {
      http.Request? captured;
      final client = StripeClient(
        apiKey: 'sk_test_123',
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'object': 'list',
              'has_more': false,
              'url': '/v1/subscriptions',
              'data': [
                {'id': 'sub_123', 'object': 'subscription'},
              ],
            }),
            200,
          );
        }),
      );

      final list = await client.subscriptions
          .list(const SubscriptionListParams(status: 'active'));

      expect(list.data, hasLength(1));
      expect(list.data.first.id, 'sub_123');
      expect(captured!.method, 'GET');
      expect(captured!.url.path, '/v1/subscriptions');
      expect(captured!.url.query, 'status=active');
    });
  });
}
