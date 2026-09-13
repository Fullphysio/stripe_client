import 'package:stripe_client/src/resources/plan.dart';
import 'package:test/test.dart';

void main() {
  group('Plan.fromJson', () {
    test('decodes a bare product id when unexpanded', () {
      final plan = Plan.fromJson({
        'id': 'plan_123',
        'object': 'plan',
        'product': 'prod_123',
        'amount': 999,
        'currency': 'usd',
        'interval': 'month',
        'interval_count': 1,
      });

      expect(plan.id, 'plan_123');
      expect(plan.product!.isExpanded, isFalse);
      expect(plan.product!.id, 'prod_123');
      expect(plan.amount, 999);
      expect(plan.currency, 'usd');
      expect(plan.interval, 'month');
      expect(plan.intervalCount, 1);
    });

    test('decodes an expanded product', () {
      final plan = Plan.fromJson({
        'id': 'plan_123',
        'object': 'plan',
        'product': {'id': 'prod_123', 'object': 'product', 'name': 'Premium'},
      });

      expect(plan.product!.isExpanded, isTrue);
      expect(plan.product!.value!.name, 'Premium');
    });

    test('leaves product null when absent', () {
      final plan = Plan.fromJson({'id': 'plan_123', 'object': 'plan'});
      expect(plan.product, isNull);
    });

    test('decodes nickname when present', () {
      final plan = Plan.fromJson({
        'id': 'plan_123',
        'object': 'plan',
        'nickname': 'Annual Premium',
      });
      expect(plan.nickname, 'Annual Premium');
    });

    test('leaves nickname null when absent', () {
      final plan = Plan.fromJson({'id': 'plan_123', 'object': 'plan'});
      expect(plan.nickname, isNull);
    });

    test('throws when id is missing', () {
      expect(
        () => Plan.fromJson(<String, Object?>{}),
        throwsA(isA<Object>()),
      );
    });

    test('toString summarises id, amount and currency', () {
      const plan = Plan(id: 'plan_123', amount: 999, currency: 'usd');
      expect(
        plan.toString(),
        'Plan(id: plan_123, amount: 999, currency: usd)',
      );
    });
  });
}
