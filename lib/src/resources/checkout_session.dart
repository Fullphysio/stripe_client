import '../core/expandable.dart';
import '../core/json_reading.dart';
import '../transport/stripe_client.dart';
import 'customer.dart';

/// The kind of Checkout Session to create, controlling which of `payment`,
/// `setup`, or `subscription` mode Stripe runs the session in.
///
/// See https://stripe.com/docs/api/checkout/sessions/create#create_checkout_session-mode.
enum CheckoutSessionMode {
  /// A one-time payment.
  payment,

  /// Sets up future off-session payments without charging the customer now.
  setup,

  /// Creates a subscription.
  subscription;

  /// The value Stripe expects on the wire for this mode.
  String get wireValue => name;
}

/// One line item of a Checkout Session, referencing a [Price] to sell.
///
/// See https://stripe.com/docs/api/checkout/sessions/create#create_checkout_session-line_items.
final class CheckoutSessionLineItemParams {
  /// Creates a line item for [price], sold in the given [quantity].
  const CheckoutSessionLineItemParams({
    required this.price,
    required this.quantity,
  });

  /// The id of the price to sell.
  final String price;

  /// How many units of [price] this line item sells.
  final int quantity;

  /// Encodes this line item the way [CheckoutSessionCreateParams.toJson]
  /// nests it under `line_items`.
  Map<String, Object?> toJson() => {'price': price, 'quantity': quantity};

  @override
  String toString() =>
      'CheckoutSessionLineItemParams(price: $price, quantity: $quantity)';
}

/// One discount to apply to a Checkout Session: a coupon, a promotion code,
/// or both provided so Stripe can pick whichever it is given.
///
/// See https://stripe.com/docs/api/checkout/sessions/create#create_checkout_session-discounts.
final class CheckoutSessionDiscountParams {
  /// Creates a discount referencing [promotionCode], [coupon], or both.
  const CheckoutSessionDiscountParams({this.promotionCode, this.coupon});

  /// The id of a promotion code to apply.
  final String? promotionCode;

  /// The id of a coupon to apply.
  final String? coupon;

  /// Encodes this discount the way [CheckoutSessionCreateParams.toJson]
  /// nests it under `discounts`.
  Map<String, Object?> toJson() => {
        if (promotionCode != null) 'promotion_code': promotionCode,
        if (coupon != null) 'coupon': coupon,
      };

  @override
  String toString() => 'CheckoutSessionDiscountParams('
      'promotionCode: $promotionCode, coupon: $coupon)';
}

/// A subset of subscription-creation parameters, passed through a
/// Checkout Session in `subscription` mode.
///
/// See https://stripe.com/docs/api/checkout/sessions/create#create_checkout_session-subscription_data.
final class CheckoutSessionSubscriptionDataParams {
  /// Creates subscription data attaching [metadata] to, and setting a
  /// [trialPeriodDays] free trial on, the subscription this session
  /// creates.
  const CheckoutSessionSubscriptionDataParams({
    this.metadata,
    this.trialPeriodDays,
  });

  /// A set of key-value pairs to attach to the subscription this session
  /// creates.
  final Map<String, String>? metadata;

  /// The number of days the subscription's initial trial period lasts,
  /// when it should have one.
  final int? trialPeriodDays;

  /// Encodes this subscription data the way
  /// [CheckoutSessionCreateParams.toJson] nests it under
  /// `subscription_data`.
  Map<String, Object?> toJson() => {
        if (metadata != null) 'metadata': metadata,
        if (trialPeriodDays != null) 'trial_period_days': trialPeriodDays,
      };

  @override
  String toString() => 'CheckoutSessionSubscriptionDataParams('
      'trialPeriodDays: $trialPeriodDays)';
}

/// Whether to collect the customer's phone number on a Checkout Session.
///
/// See https://stripe.com/docs/api/checkout/sessions/create#create_checkout_session-phone_number_collection.
final class CheckoutSessionPhoneNumberCollectionParams {
  /// Creates phone number collection settings, enabling or disabling the
  /// phone number field on the checkout page.
  const CheckoutSessionPhoneNumberCollectionParams({required this.enabled});

  /// Whether to display a phone number input on the checkout page.
  final bool enabled;

  /// Encodes this setting the way [CheckoutSessionCreateParams.toJson]
  /// nests it under `phone_number_collection`.
  Map<String, Object?> toJson() => {'enabled': enabled};

  @override
  String toString() =>
      'CheckoutSessionPhoneNumberCollectionParams(enabled: $enabled)';
}

/// Whether to collect a tax ID from the customer on a Checkout Session.
///
/// See https://stripe.com/docs/api/checkout/sessions/create#create_checkout_session-tax_id_collection.
final class CheckoutSessionTaxIdCollectionParams {
  /// Creates tax ID collection settings, enabling or disabling the tax ID
  /// field on the checkout page.
  const CheckoutSessionTaxIdCollectionParams({required this.enabled});

  /// Whether to display a tax ID input on the checkout page.
  final bool enabled;

  /// Encodes this setting the way [CheckoutSessionCreateParams.toJson]
  /// nests it under `tax_id_collection`.
  Map<String, Object?> toJson() => {'enabled': enabled};

  @override
  String toString() =>
      'CheckoutSessionTaxIdCollectionParams(enabled: $enabled)';
}

/// Whether Stripe Tax should calculate tax automatically on a Checkout
/// Session.
///
/// See https://stripe.com/docs/api/checkout/sessions/create#create_checkout_session-automatic_tax.
final class CheckoutSessionAutomaticTaxParams {
  /// Creates automatic tax settings, enabling or disabling Stripe Tax for
  /// this session.
  const CheckoutSessionAutomaticTaxParams({required this.enabled});

  /// Whether Stripe Tax calculates tax automatically on this session.
  final bool enabled;

  /// Encodes this setting the way [CheckoutSessionCreateParams.toJson]
  /// nests it under `automatic_tax`.
  Map<String, Object?> toJson() => {'enabled': enabled};

  @override
  String toString() => 'CheckoutSessionAutomaticTaxParams(enabled: $enabled)';
}

/// Controls whether Checkout saves address, name, and shipping details back
/// onto [CheckoutSessionCreateParams.customer], when the session has one.
///
/// See https://stripe.com/docs/api/checkout/sessions/create#create_checkout_session-customer_update.
final class CheckoutSessionCustomerUpdateParams {
  /// Creates customer-update settings. Each parameter accepts `'auto'` (let
  /// Checkout decide) or `'never'` (leave the customer untouched); Stripe
  /// rejects any other value.
  const CheckoutSessionCustomerUpdateParams({
    this.address,
    this.name,
    this.shipping,
  });

  /// Whether to save the address Checkout collects onto the customer.
  final String? address;

  /// Whether to save the name Checkout collects onto the customer.
  final String? name;

  /// Whether to save the shipping details Checkout collects onto the
  /// customer.
  final String? shipping;

  /// Encodes this setting the way [CheckoutSessionCreateParams.toJson]
  /// nests it under `customer_update`, omitting whichever fields are null.
  Map<String, Object?> toJson() => {
        if (address != null) 'address': address,
        if (name != null) 'name': name,
        if (shipping != null) 'shipping': shipping,
      };

  @override
  String toString() => 'CheckoutSessionCustomerUpdateParams('
      'address: $address, name: $name, shipping: $shipping)';
}

/// Parameters for creating a Checkout Session.
///
/// See https://stripe.com/docs/api/checkout/sessions/create.
final class CheckoutSessionCreateParams {
  /// Creates the parameters for a session in the given [mode], selling
  /// [lineItems], redirecting to [successUrl] on completion or [cancelUrl]
  /// if the customer abandons it.
  const CheckoutSessionCreateParams({
    required this.mode,
    required this.lineItems,
    required this.successUrl,
    required this.cancelUrl,
    this.customer,
    this.customerEmail,
    this.discounts,
    this.subscriptionData,
    this.metadata,
    this.clientReferenceId,
    this.locale,
    this.allowPromotionCodes,
    this.phoneNumberCollection,
    this.taxIdCollection,
    this.automaticTax,
    this.customerUpdate,
    this.billingAddressCollection,
  });

  /// Which kind of session to create.
  final CheckoutSessionMode mode;

  /// The items the customer is purchasing.
  final List<CheckoutSessionLineItemParams> lineItems;

  /// Where to redirect the customer once checkout is complete.
  final String successUrl;

  /// Where to redirect the customer if they cancel checkout.
  final String cancelUrl;

  /// An existing customer to associate this session with, when there is
  /// one.
  final String? customer;

  /// The email address to pre-fill on the checkout form, when the session
  /// has no [customer] to read one from.
  final String? customerEmail;

  /// The coupons and promotion codes to apply to this session.
  final List<CheckoutSessionDiscountParams>? discounts;

  /// Subscription-creation parameters, when [mode] is
  /// [CheckoutSessionMode.subscription].
  final CheckoutSessionSubscriptionDataParams? subscriptionData;

  /// A set of key-value pairs to attach to the session.
  final Map<String, String>? metadata;

  /// A unique string to reference this session with, meant to match it to
  /// a record in the caller's own system.
  final String? clientReferenceId;

  /// The IETF language tag to render the checkout UI in, or `'auto'` to let
  /// Stripe detect one.
  final String? locale;

  /// Whether to let the customer enter a promotion code themselves on the
  /// checkout page.
  final bool? allowPromotionCodes;

  /// Whether to collect the customer's phone number on the checkout page.
  final CheckoutSessionPhoneNumberCollectionParams? phoneNumberCollection;

  /// Whether to collect a tax ID from the customer on the checkout page.
  final CheckoutSessionTaxIdCollectionParams? taxIdCollection;

  /// Whether Stripe Tax calculates tax automatically for this session.
  final CheckoutSessionAutomaticTaxParams? automaticTax;

  /// Whether Checkout saves address, name, and shipping details back onto
  /// [customer].
  final CheckoutSessionCustomerUpdateParams? customerUpdate;

  /// Whether to require a billing address on the checkout page: pass
  /// `'required'` to force collection, or leave `null` to let Stripe decide.
  final String? billingAddressCollection;

  /// Encodes these parameters the way [CheckoutSessionsService.create]
  /// sends them: [lineItems] and [discounts] become the indexed-array wire
  /// shape (`line_items[0][price]=...`) the existing form encoder produces
  /// from a `List<Map>` value.
  Map<String, Object?> toJson() => {
        'mode': mode.wireValue,
        'line_items': lineItems.map((item) => item.toJson()).toList(),
        'success_url': successUrl,
        'cancel_url': cancelUrl,
        if (customer != null) 'customer': customer,
        if (customerEmail != null) 'customer_email': customerEmail,
        if (discounts != null)
          'discounts': discounts!.map((discount) => discount.toJson()).toList(),
        if (subscriptionData != null)
          'subscription_data': subscriptionData!.toJson(),
        if (metadata != null) 'metadata': metadata,
        if (clientReferenceId != null) 'client_reference_id': clientReferenceId,
        if (locale != null) 'locale': locale,
        if (allowPromotionCodes != null)
          'allow_promotion_codes': allowPromotionCodes,
        if (phoneNumberCollection != null)
          'phone_number_collection': phoneNumberCollection!.toJson(),
        if (taxIdCollection != null)
          'tax_id_collection': taxIdCollection!.toJson(),
        if (automaticTax != null) 'automatic_tax': automaticTax!.toJson(),
        if (customerUpdate != null) 'customer_update': customerUpdate!.toJson(),
        if (billingAddressCollection != null)
          'billing_address_collection': billingAddressCollection,
      };

  @override
  String toString() => 'CheckoutSessionCreateParams(mode: $mode, '
      'lineItems: ${lineItems.length})';
}

/// A Stripe Checkout Session: a hosted, pre-built payment page.
///
/// See https://stripe.com/docs/api/checkout/sessions/object.
final class CheckoutSession {
  /// Creates a session directly from already-decoded fields.
  const CheckoutSession({
    required this.id,
    this.url,
    this.customer,
    this.subscription,
    this.clientReferenceId,
    this.mode,
    this.status,
  });

  /// Decodes [json] into a [CheckoutSession].
  factory CheckoutSession.fromJson(Map<String, Object?> json) =>
      CheckoutSession(
        id: json.requireString('id', 'CheckoutSession'),
        url: json.optString('url'),
        customer: switch (json['customer']) {
          null => null,
          final customerJson => Expandable<Customer>.fromJson(
              customerJson,
              Customer.fromJson,
              (customer) => customer.id,
              fieldName: 'checkout_session.customer',
            ),
        },
        subscription: switch (json['subscription']) {
          null => null,
          final subscriptionJson => Expandable<StripeStub>.fromJson(
              subscriptionJson,
              StripeStub.fromJson,
              StripeStub.idOf,
              fieldName: 'checkout_session.subscription',
            ),
        },
        clientReferenceId: json.optString('client_reference_id'),
        mode: json.optString('mode'),
        status: json.optString('status'),
      );

  /// The session's unique identifier.
  final String id;

  /// The URL the customer should be redirected to in order to complete
  /// checkout, when Stripe sent one.
  final String? url;

  /// The customer this session is for — either a bare id, or the expanded
  /// [Customer] when the request expanded `customer`.
  final Expandable<Customer>? customer;

  /// The subscription this session created, when it ran in
  /// [CheckoutSessionMode.subscription] mode — either a bare id, or the
  /// expanded object when the request expanded `subscription`. Left as a
  /// [StripeStub] rather than a typed `Subscription` to avoid this
  /// resource depending on that one.
  final Expandable<StripeStub>? subscription;

  /// The caller-supplied reference string this session was created with.
  final String? clientReferenceId;

  /// The mode this session was created in: `'payment'`, `'setup'`, or
  /// `'subscription'`.
  final String? mode;

  /// The status of this session: `'open'`, `'complete'`, or `'expired'`.
  final String? status;

  @override
  String toString() => 'CheckoutSession(id: $id, mode: $mode, status: $status)';
}

/// Checkout Session operations: `client.checkout.sessions.create(...)`.
final class CheckoutSessionsService {
  /// Creates the service backed by [_client].
  CheckoutSessionsService(this._client);

  final StripeClient _client;

  /// Creates a checkout session with the given [params].
  ///
  /// [idempotencyKey] overrides the automatically generated key that makes
  /// retries of this call safe; see [StripeClient.request].
  Future<CheckoutSession> create(
    CheckoutSessionCreateParams params, {
    String? idempotencyKey,
  }) async {
    final json = await _client.request(
      method: 'POST',
      path: '/v1/checkout/sessions',
      params: params.toJson(),
      idempotencyKey: idempotencyKey,
    );
    return CheckoutSession.fromJson(json as Map<String, Object?>);
  }
}
