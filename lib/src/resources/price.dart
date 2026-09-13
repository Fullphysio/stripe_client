import '../core/expandable.dart';
import '../core/json_reading.dart';
import '../transport/stripe_client.dart';
import 'product.dart';

/// The recurring billing details of a [Price], present when that price is
/// for a subscription rather than a one-off purchase.
///
/// See https://stripe.com/docs/api/prices/object#price_object-recurring.
final class PriceRecurring {
  /// Creates recurring billing details directly from already-decoded fields.
  const PriceRecurring({this.interval, this.intervalCount});

  /// Decodes [json] into a [PriceRecurring].
  factory PriceRecurring.fromJson(Map<String, Object?> json) => PriceRecurring(
        interval: json.optString('interval'),
        intervalCount: json.optInt('interval_count'),
      );

  /// The frequency at which this price is billed: `'day'`, `'week'`,
  /// `'month'`, or `'year'`.
  final String? interval;

  /// The number of intervals (specified in [interval]) between subscription
  /// billings — for example, [intervalCount] of 3 with [interval] `'month'`
  /// bills every three months.
  final int? intervalCount;

  @override
  String toString() =>
      'PriceRecurring(interval: $interval, intervalCount: $intervalCount)';
}

/// A Stripe Price: how much, and how often, a [Product] is charged for.
///
/// See https://stripe.com/docs/api/prices/object.
final class Price {
  /// Creates a price directly from already-decoded fields.
  const Price({
    required this.id,
    this.unitAmount,
    this.currency,
    this.product,
    this.recurring,
  });

  /// Decodes [json] into a [Price].
  factory Price.fromJson(Map<String, Object?> json) => Price(
        id: json.requireString('id', 'Price'),
        unitAmount: json.optInt('unit_amount'),
        currency: json.optString('currency'),
        product: switch (json['product']) {
          null => null,
          final productJson => Expandable<Product>.fromJson(
              productJson,
              Product.fromJson,
              (product) => product.id,
              fieldName: 'price.product',
            ),
        },
        recurring: json.optNested('recurring', PriceRecurring.fromJson),
      );

  /// The price's unique identifier.
  final String id;

  /// The unit amount in cents (or local equivalent) to be charged, when the
  /// price is not built from tiers or a custom amount.
  final int? unitAmount;

  /// Three-letter ISO currency code, in lowercase.
  final String? currency;

  /// The product this price is for — either a bare id, or the expanded
  /// [Product] when the request expanded `product`.
  final Expandable<Product>? product;

  /// The recurring billing details, when this price is for a subscription
  /// rather than a one-off purchase.
  final PriceRecurring? recurring;

  @override
  String toString() =>
      'Price(id: $id, unitAmount: $unitAmount, currency: $currency)';
}

/// Price operations: `client.prices.retrieve(id)`.
final class PricesService {
  /// Creates the service backed by [_client].
  PricesService(this._client);

  final StripeClient _client;

  /// Retrieves the price with the given [id].
  Future<Price> retrieve(String id) async {
    final json = await _client.request(method: 'GET', path: '/v1/prices/$id');
    return Price.fromJson(json as Map<String, Object?>);
  }
}
