import '../core/expandable.dart';
import '../core/json_reading.dart';
import 'product.dart';

/// A Stripe Plan: the legacy sibling of [Price] that still appears embedded
/// on a subscription item's `plan` field for backward compatibility.
///
/// Stripe no longer lets callers create new plans — new integrations use
/// [Price] exclusively — but existing subscription items still carry one,
/// and some production code reads `plan.id` / `plan.product` rather than the
/// equivalent [Price] fields. There is no service for this resource: a plan
/// is only ever read nested off a [SubscriptionItem].
///
/// See https://stripe.com/docs/api/plans/object.
final class Plan {
  /// Creates a plan directly from already-decoded fields.
  const Plan({
    required this.id,
    this.product,
    this.amount,
    this.currency,
    this.interval,
    this.intervalCount,
    this.nickname,
  });

  /// Decodes [json] into a [Plan].
  factory Plan.fromJson(Map<String, Object?> json) => Plan(
        id: json.requireString('id', 'Plan'),
        product: switch (json['product']) {
          null => null,
          final productJson => Expandable<Product>.fromJson(
              productJson,
              Product.fromJson,
              (product) => product.id,
              fieldName: 'plan.product',
            ),
        },
        amount: json.optInt('amount'),
        currency: json.optString('currency'),
        interval: json.optString('interval'),
        intervalCount: json.optInt('interval_count'),
        nickname: json.optString('nickname'),
      );

  /// The plan's unique identifier.
  final String id;

  /// The product this plan is for — either a bare id, or the expanded
  /// [Product] when the request expanded `plan.product`.
  final Expandable<Product>? product;

  /// The amount in cents (or local equivalent) to be charged on the
  /// interval specified by [interval].
  final int? amount;

  /// Three-letter ISO currency code, in lowercase.
  final String? currency;

  /// The frequency at which a subscription is billed: `'day'`, `'week'`,
  /// `'month'`, or `'year'`.
  final String? interval;

  /// The number of intervals (specified in [interval]) between subscription
  /// billings.
  final int? intervalCount;

  /// A brief description of the plan, hidden from customers. Callers use it
  /// as a display name when the expanded [product] is unavailable.
  final String? nickname;

  @override
  String toString() => 'Plan(id: $id, amount: $amount, currency: $currency)';
}
