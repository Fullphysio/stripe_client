import 'package:stripe_client/src/resources/discount.dart';
import 'package:test/test.dart';

void main() {
  group('DiscountSource.fromJson', () {
    test('decodes a bare coupon id when unexpanded', () {
      final source =
          DiscountSource.fromJson({'coupon': 'coupon_123', 'type': 'coupon'});
      expect(source.coupon!.isExpanded, isFalse);
      expect(source.coupon!.id, 'coupon_123');
      expect(source.type, 'coupon');
    });

    test('decodes an expanded coupon', () {
      final source = DiscountSource.fromJson({
        'coupon': {'id': 'coupon_123', 'object': 'coupon', 'name': 'Half off'},
        'type': 'coupon',
      });
      expect(source.coupon!.isExpanded, isTrue);
      expect(source.coupon!.value!.name, 'Half off');
    });

    test('leaves coupon null when absent', () {
      final source = DiscountSource.fromJson(<String, Object?>{});
      expect(source.coupon, isNull);
      expect(source.type, isNull);
    });

    test('toString summarises coupon and type', () {
      const source = DiscountSource(type: 'coupon');
      expect(source.toString(), 'DiscountSource(coupon: null, type: coupon)');
    });
  });

  group('Discount.fromJson', () {
    test('reads coupon through discount.source.coupon, not discount.coupon',
        () {
      final discount = Discount.fromJson({
        'id': 'di_123',
        'object': 'discount',
        'source': {
          'type': 'coupon',
          'coupon': {'id': 'coupon_123', 'object': 'coupon', 'amount_off': 500},
        },
        'start': 1731600000,
      });

      expect(discount.id, 'di_123');
      expect(discount.source!.coupon!.isExpanded, isTrue);
      expect(discount.coupon!.id, 'coupon_123');
      expect(discount.coupon!.amountOff, 500);
      expect(discount.start,
          DateTime.fromMillisecondsSinceEpoch(1731600000000, isUtc: true));
    });

    test('decodes a bare promotion_code id when unexpanded', () {
      final discount = Discount.fromJson({
        'id': 'di_123',
        'object': 'discount',
        'promotion_code': 'promo_123',
      });

      expect(discount.promotionCode!.isExpanded, isFalse);
      expect(discount.promotionCode!.id, 'promo_123');
    });

    test('decodes an expanded promotion_code', () {
      final discount = Discount.fromJson({
        'id': 'di_123',
        'object': 'discount',
        'promotion_code': {
          'id': 'promo_123',
          'object': 'promotion_code',
          'code': 'SAVE10',
        },
      });

      expect(discount.promotionCode!.isExpanded, isTrue);
      expect(discount.promotionCode!.value!.code, 'SAVE10');
    });

    test('coupon getter returns null when source is absent', () {
      final discount =
          Discount.fromJson({'id': 'di_123', 'object': 'discount'});
      expect(discount.source, isNull);
      expect(discount.coupon, isNull);
      expect(discount.promotionCode, isNull);
      expect(discount.end, isNull);
    });

    test('throws when id is missing', () {
      expect(
        () => Discount.fromJson(<String, Object?>{}),
        throwsA(isA<Object>()),
      );
    });

    test('toString summarises id and source', () {
      const discount = Discount(id: 'di_123');
      expect(discount.toString(), 'Discount(id: di_123, source: null)');
    });
  });
}
