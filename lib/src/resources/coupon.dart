import '../core/json_reading.dart';

/// A Stripe Coupon: a discount to apply to a customer's subscription or
/// invoice.
///
/// There is no service for this resource: a coupon is only ever read nested
/// off a `Discount` or a `PromotionCode`'s `promotion` field, never fetched
/// directly by this package.
///
/// See https://stripe.com/docs/api/coupons/object.
final class Coupon {
  /// Creates a coupon directly from already-decoded fields.
  const Coupon({
    required this.id,
    this.amountOff,
    this.percentOff,
    this.name,
    this.duration,
  });

  /// Decodes [json] into a [Coupon].
  factory Coupon.fromJson(Map<String, Object?> json) => Coupon(
        id: json.requireString('id', 'Coupon'),
        amountOff: json.optInt('amount_off'),
        percentOff: json.optDouble('percent_off'),
        name: json.optString('name'),
        duration: json.optString('duration'),
      );

  /// The coupon's unique identifier.
  final String id;

  /// The amount, in cents (or local equivalent), this coupon takes off the
  /// subtotal, when it is a fixed-amount coupon.
  final int? amountOff;

  /// The percentage this coupon takes off the subtotal, when it is a
  /// percentage-based coupon.
  final double? percentOff;

  /// The name Stripe displays for this coupon, meant to be customer-facing.
  final String? name;

  /// How long the discount applies once redeemed: `'forever'`, `'once'`, or
  /// `'repeating'`.
  final String? duration;

  @override
  String toString() =>
      'Coupon(id: $id, amountOff: $amountOff, percentOff: $percentOff)';
}
