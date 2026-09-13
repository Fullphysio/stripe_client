import '../core/expand_params.dart';
import '../core/expandable.dart';
import '../core/json_reading.dart';
import '../core/stripe_list.dart';
import '../transport/stripe_client.dart';
import 'coupon.dart';
import 'customer.dart';

/// The promotion a [PromotionCode] redeems.
///
/// Despite the field's popular name, Stripe does not expose
/// `promotion_code.coupon` directly: the coupon is nested one level deeper,
/// under a `promotion` object that also carries a `type` discriminator
/// (currently always `'coupon'`). Stripe's schema names this shape
/// `promotion_codes_resource_promotion`.
///
/// See https://stripe.com/docs/api/promotion_codes/object.
final class PromotionCodePromotion {
  /// Creates a promotion directly from already-decoded fields.
  const PromotionCodePromotion({required this.coupon, this.type});

  /// Decodes [json] into a [PromotionCodePromotion].
  factory PromotionCodePromotion.fromJson(Map<String, Object?> json) =>
      PromotionCodePromotion(
        coupon: Expandable<Coupon>.fromJson(
          json['coupon'],
          Coupon.fromJson,
          (coupon) => coupon.id,
          fieldName: 'promotion_code.promotion.coupon',
        ),
        type: json.optString('type'),
      );

  /// The coupon this promotion redeems — either a bare id, or the expanded
  /// [Coupon] when the request expanded `promotion.coupon`.
  final Expandable<Coupon> coupon;

  /// The type of this promotion. Currently always `'coupon'`.
  final String? type;

  @override
  String toString() => 'PromotionCodePromotion(coupon: $coupon, type: $type)';
}

/// The restrictions placed on when a [PromotionCode] can be redeemed.
///
/// See https://stripe.com/docs/api/promotion_codes/object#promotion_code_object-restrictions.
final class PromotionCodeRestrictions {
  /// Creates restrictions directly from already-decoded fields.
  const PromotionCodeRestrictions({
    this.firstTimeTransaction,
    this.minimumAmount,
    this.minimumAmountCurrency,
  });

  /// Decodes [json] into a [PromotionCodeRestrictions].
  factory PromotionCodeRestrictions.fromJson(Map<String, Object?> json) =>
      PromotionCodeRestrictions(
        firstTimeTransaction: json.optBool('first_time_transaction'),
        minimumAmount: json.optInt('minimum_amount'),
        minimumAmountCurrency: json.optString('minimum_amount_currency'),
      );

  /// Whether this promotion code can only be redeemed for a customer's
  /// first transaction.
  final bool? firstTimeTransaction;

  /// The minimum amount, in cents (or local equivalent), required to
  /// redeem this code, when there is one.
  final int? minimumAmount;

  /// The currency [minimumAmount] is denominated in, when there is a
  /// minimum.
  final String? minimumAmountCurrency;

  @override
  String toString() => 'PromotionCodeRestrictions('
      'firstTimeTransaction: $firstTimeTransaction, '
      'minimumAmount: $minimumAmount)';
}

/// A Stripe Promotion Code: a customer-facing code that redeems a [Coupon].
///
/// See https://stripe.com/docs/api/promotion_codes/object.
final class PromotionCode {
  /// Creates a promotion code directly from already-decoded fields.
  const PromotionCode({
    required this.id,
    this.code,
    this.active,
    this.promotion,
    this.timesRedeemed,
    this.maxRedemptions,
    this.expiresAt,
    this.restrictions,
    this.customer,
  });

  /// Decodes [json] into a [PromotionCode].
  factory PromotionCode.fromJson(Map<String, Object?> json) => PromotionCode(
        id: json.requireString('id', 'PromotionCode'),
        code: json.optString('code'),
        active: json.optBool('active'),
        promotion: json.optNested('promotion', PromotionCodePromotion.fromJson),
        timesRedeemed: json.optInt('times_redeemed'),
        maxRedemptions: json.optInt('max_redemptions'),
        expiresAt: json.optUnixTime('expires_at'),
        restrictions:
            json.optNested('restrictions', PromotionCodeRestrictions.fromJson),
        customer: switch (json['customer']) {
          null => null,
          final customerJson => Expandable<Customer>.fromJson(
              customerJson,
              Customer.fromJson,
              (customer) => customer.id,
              fieldName: 'promotion_code.customer',
            ),
        },
      );

  /// The promotion code's unique identifier.
  final String id;

  /// The customer-facing code redeemable for a discount, for example
  /// `'BLACKFRIDAY'`.
  final String? code;

  /// Whether this promotion code is currently active. A code can be
  /// deactivated even though its underlying coupon still exists.
  final bool? active;

  /// The promotion this code redeems, nesting the coupon under Stripe's
  /// `promotion` field.
  final PromotionCodePromotion? promotion;

  /// The number of times this promotion code has been redeemed.
  final int? timesRedeemed;

  /// The maximum number of times this promotion code can be redeemed, when
  /// there is a limit.
  final int? maxRedemptions;

  /// When this promotion code expires, when it is set to.
  final DateTime? expiresAt;

  /// The restrictions on when this code can be redeemed.
  final PromotionCodeRestrictions? restrictions;

  /// The customer this promotion code is restricted to, when it is
  /// restricted to one — either a bare id, or the expanded [Customer] when
  /// the request expanded `customer`.
  final Expandable<Customer>? customer;

  /// The coupon this code redeems, read through [promotion] — Stripe nests
  /// it there rather than directly on the promotion code, but every call
  /// site wants this shortcut.
  Coupon? get coupon => promotion?.coupon.value;

  @override
  String toString() => 'PromotionCode(id: $id, code: $code, active: $active)';
}

/// Parameters for creating a Promotion Code.
///
/// See https://stripe.com/docs/api/promotion_codes/create.
final class PromotionCodeCreateParams {
  /// Creates the parameters for a promotion code redeeming [coupon].
  ///
  /// [code] is the customer-facing string; Stripe generates one when it is
  /// omitted. [customer] restricts redemption to a single customer.
  /// [active] can be set to `false` to create the code already deactivated.
  /// [maxRedemptions] caps how many times the code can be redeemed, and
  /// [expiresAt] sets when it stops being redeemable.
  const PromotionCodeCreateParams({
    required this.coupon,
    this.code,
    this.customer,
    this.active,
    this.maxRedemptions,
    this.expiresAt,
    this.metadata,
  });

  /// The id of the coupon this promotion code redeems.
  final String coupon;

  /// The customer-facing code, when overriding Stripe's auto-generated one.
  final String? code;

  /// The customer this promotion code is restricted to, when restricting it
  /// to one.
  final String? customer;

  /// Whether the promotion code is active as soon as it is created.
  final bool? active;

  /// The maximum number of times this promotion code can be redeemed.
  final int? maxRedemptions;

  /// When this promotion code stops being redeemable.
  final DateTime? expiresAt;

  /// A set of key-value pairs to attach to the promotion code.
  final Map<String, String>? metadata;

  /// Encodes these parameters the way [PromotionCodesService.create] sends
  /// them: [coupon] is wrapped in the nested `promotion` object Stripe's API
  /// requires (`{'type': 'coupon', 'coupon': coupon}`), hiding that
  /// single-legal-value `type` field from callers entirely.
  Map<String, Object?> toJson() => {
        'promotion': {'type': 'coupon', 'coupon': coupon},
        if (code != null) 'code': code,
        if (customer != null) 'customer': customer,
        if (active != null) 'active': active,
        if (maxRedemptions != null) 'max_redemptions': maxRedemptions,
        if (expiresAt != null) 'expires_at': expiresAt,
        if (metadata != null) 'metadata': metadata,
      };

  @override
  String toString() => 'PromotionCodeCreateParams(coupon: $coupon, '
      'code: $code)';
}

/// Parameters for listing Promotion Codes.
///
/// See https://stripe.com/docs/api/promotion_codes/list.
final class PromotionCodeListParams {
  /// Creates the parameters, filtering by [code], [active], or [customer]
  /// when given, capping the page at [limit], and requesting [expand] on
  /// each returned promotion code.
  const PromotionCodeListParams({
    this.code,
    this.active,
    this.limit,
    this.customer,
    this.expand,
  });

  /// Only return promotion codes with this customer-facing code.
  final String? code;

  /// Only return promotion codes that are active, or inactive.
  final bool? active;

  /// A limit on the number of objects to return, between 1 and 100.
  final int? limit;

  /// Only return promotion codes restricted to this customer.
  final String? customer;

  /// The dotted field paths to expand on each returned promotion code.
  final List<String>? expand;

  /// Encodes these parameters the way [PromotionCodesService.list] sends
  /// them.
  Map<String, Object?> toJson() => {
        if (code != null) 'code': code,
        if (active != null) 'active': active,
        if (limit != null) 'limit': limit,
        if (customer != null) 'customer': customer,
        if (expand != null) 'expand': expand,
      };

  @override
  String toString() => 'PromotionCodeListParams(code: $code, '
      'active: $active, customer: $customer)';
}

/// Promotion Code operations: `client.promotionCodes.create(...)`,
/// `client.promotionCodes.retrieve(id)`, `client.promotionCodes.list(...)`.
final class PromotionCodesService {
  /// Creates the service backed by [_client].
  PromotionCodesService(this._client);

  final StripeClient _client;

  /// Creates a promotion code with the given [params].
  ///
  /// [idempotencyKey] overrides the automatically generated key that makes
  /// retries of this call safe; see [StripeClient.request].
  Future<PromotionCode> create(
    PromotionCodeCreateParams params, {
    String? idempotencyKey,
  }) async {
    final json = await _client.request(
      method: 'POST',
      path: '/v1/promotion_codes',
      params: params.toJson(),
      idempotencyKey: idempotencyKey,
    );
    return PromotionCode.fromJson(json as Map<String, Object?>);
  }

  /// Retrieves the promotion code with the given [id].
  Future<PromotionCode> retrieve(String id, [ExpandParams? params]) async {
    final json = await _client.request(
      method: 'GET',
      path: '/v1/promotion_codes/$id',
      params: params?.toJson(),
    );
    return PromotionCode.fromJson(json as Map<String, Object?>);
  }

  /// Lists promotion codes, optionally filtered and paged by [params].
  Future<StripeList<PromotionCode>> list([
    PromotionCodeListParams? params,
  ]) async {
    final json = await _client.request(
      method: 'GET',
      path: '/v1/promotion_codes',
      params: params?.toJson(),
    );
    return StripeList<PromotionCode>.fromJson(json, PromotionCode.fromJson);
  }
}
