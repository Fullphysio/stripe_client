import '../core/expandable.dart';
import '../core/json_reading.dart';
import 'coupon.dart';
import 'promotion_code.dart';

/// The coupon a [Discount] is built from, and the discriminator identifying
/// what kind of discount it is.
///
/// Stripe nests the coupon one level deeper than the name `discount.coupon`
/// suggests: the wire shape is `discount.source.coupon`, not
/// `discount.coupon` directly — this class models that `source` object.
/// Currently `type` is always `'coupon'`, but the field exists on the wire so
/// future discount sources (Stripe's schema names this `discount_source`)
/// don't require a breaking change to add.
///
/// See https://stripe.com/docs/api/discounts/object.
final class DiscountSource {
  /// Creates a discount source directly from already-decoded fields.
  const DiscountSource({this.coupon, this.type});

  /// Decodes [json] into a [DiscountSource].
  factory DiscountSource.fromJson(Map<String, Object?> json) => DiscountSource(
        coupon: switch (json['coupon']) {
          null => null,
          final couponJson => Expandable<Coupon>.fromJson(
              couponJson,
              Coupon.fromJson,
              (coupon) => coupon.id,
              fieldName: 'discount.source.coupon',
            ),
        },
        type: json.optString('type'),
      );

  /// The coupon backing this discount — either a bare id, or the expanded
  /// [Coupon] when the request expanded `source.coupon`.
  final Expandable<Coupon>? coupon;

  /// The type of this discount source. Currently always `'coupon'`.
  final String? type;

  @override
  String toString() => 'DiscountSource(coupon: $coupon, type: $type)';
}

/// A Stripe Discount: a coupon or promotion code applied to a customer,
/// subscription, or invoice.
///
/// There is no service for this resource: a discount is only ever read
/// nested off another object, such as `Subscription.discounts` or
/// `Invoice.discounts`.
///
/// See https://stripe.com/docs/api/discounts/object.
final class Discount {
  /// Creates a discount directly from already-decoded fields.
  const Discount({
    required this.id,
    this.source,
    this.promotionCode,
    this.start,
    this.end,
  });

  /// Decodes [json] into a [Discount].
  factory Discount.fromJson(Map<String, Object?> json) => Discount(
        id: json.requireString('id', 'Discount'),
        source: json.optNested('source', DiscountSource.fromJson),
        promotionCode: switch (json['promotion_code']) {
          null => null,
          final promotionCodeJson => Expandable<PromotionCode>.fromJson(
              promotionCodeJson,
              PromotionCode.fromJson,
              (promotionCode) => promotionCode.id,
              fieldName: 'discount.promotion_code',
            ),
        },
        start: json.optUnixTime('start'),
        end: json.optUnixTime('end'),
      );

  /// The discount's unique identifier.
  final String id;

  /// The coupon and discount-kind discriminator this discount is built
  /// from, nested under Stripe's `source` field.
  final DiscountSource? source;

  /// The promotion code that was used to redeem this discount — either a
  /// bare id, or the expanded [PromotionCode] when the request expanded
  /// `discounts.promotion_code`.
  final Expandable<PromotionCode>? promotionCode;

  /// When this discount started being active.
  final DateTime? start;

  /// When this discount will end, when it is scheduled to.
  final DateTime? end;

  /// The coupon this discount was built from, read through [source] —
  /// Stripe nests it there rather than directly on the discount, but every
  /// call site wants this shortcut.
  Coupon? get coupon => source?.coupon?.value;

  @override
  String toString() => 'Discount(id: $id, source: $source)';
}
