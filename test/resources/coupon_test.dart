import 'package:stripe_client/src/resources/coupon.dart';
import 'package:test/test.dart';

void main() {
  group('Coupon.fromJson', () {
    test('decodes an amount-off coupon', () {
      final coupon = Coupon.fromJson({
        'id': 'coupon_123',
        'object': 'coupon',
        'amount_off': 500,
        'name': 'Five off',
        'duration': 'once',
      });

      expect(coupon.id, 'coupon_123');
      expect(coupon.amountOff, 500);
      expect(coupon.percentOff, isNull);
      expect(coupon.name, 'Five off');
      expect(coupon.duration, 'once');
    });

    test('decodes a percent-off coupon', () {
      final coupon = Coupon.fromJson({
        'id': 'coupon_456',
        'object': 'coupon',
        'percent_off': 12.5,
        'duration': 'repeating',
      });

      expect(coupon.amountOff, isNull);
      expect(coupon.percentOff, 12.5);
    });

    test('throws when id is missing', () {
      expect(
        () => Coupon.fromJson(<String, Object?>{}),
        throwsA(isA<Object>()),
      );
    });

    test('toString summarises id, amountOff and percentOff', () {
      const coupon = Coupon(id: 'coupon_123', amountOff: 500);
      expect(
        coupon.toString(),
        'Coupon(id: coupon_123, amountOff: 500, percentOff: null)',
      );
    });
  });
}
