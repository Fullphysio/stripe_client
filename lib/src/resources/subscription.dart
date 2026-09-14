import '../core/expand_params.dart';
import '../core/expandable.dart';
import '../core/json_reading.dart';
import '../core/stripe_list.dart';
import '../transport/stripe_client.dart';
import 'customer.dart';
import 'discount.dart';
import 'invoice.dart';
import 'plan.dart';
import 'price.dart';

/// One item of a [Subscription], pricing a single product on the
/// subscription.
///
/// Unlike [Subscription] itself, a subscription item is where
/// `current_period_start` and `current_period_end` actually live in the
/// current Stripe API — see [Subscription.currentPeriodStart] for why that
/// matters. [price] and [plan] are decoded as plain nested objects rather
/// than [Expandable], because Stripe always embeds both directly on an
/// item; they are never represented as a bare id here.
///
/// See https://stripe.com/docs/api/subscription_items/object.
final class SubscriptionItem {
  /// Creates a subscription item directly from already-decoded fields.
  const SubscriptionItem({
    required this.id,
    this.price,
    this.plan,
    this.quantity,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    this.discounts = const [],
  });

  /// Decodes [json] into a [SubscriptionItem].
  factory SubscriptionItem.fromJson(Map<String, Object?> json) =>
      SubscriptionItem(
        id: json.requireString('id', 'SubscriptionItem'),
        price: json.optNested('price', Price.fromJson),
        plan: json.optNested('plan', Plan.fromJson),
        quantity: json.optInt('quantity'),
        currentPeriodStart: json.optUnixTime('current_period_start'),
        currentPeriodEnd: json.optUnixTime('current_period_end'),
        discounts: json.optList<Expandable<Discount>>(
          'discounts',
          (element) => Expandable<Discount>.fromJson(
            element,
            Discount.fromJson,
            (discount) => discount.id,
            fieldName: 'subscription_item.discounts[]',
          ),
        ),
      );

  /// The subscription item's unique identifier.
  final String id;

  /// The price this item is charged at, embedded directly by Stripe (never
  /// a bare id).
  final Price? price;

  /// The legacy plan this item is charged at, embedded directly by Stripe
  /// alongside [price] for backward compatibility.
  final Plan? plan;

  /// How many units of [price] (or [plan]) this item is subscribed to.
  final int? quantity;

  /// The start of the current billing period this item is in.
  ///
  /// This lives on the subscription item in the current Stripe API, not on
  /// the subscription itself — see [Subscription.currentPeriodStart].
  final DateTime? currentPeriodStart;

  /// The end of the current billing period this item is in.
  ///
  /// This lives on the subscription item in the current Stripe API, not on
  /// the subscription itself — see [Subscription.currentPeriodEnd].
  final DateTime? currentPeriodEnd;

  /// The discounts applied to this item — each either a bare id, or the
  /// expanded [Discount] when the request expanded `items.data.discounts`.
  final List<Expandable<Discount>> discounts;

  @override
  String toString() => 'SubscriptionItem(id: $id, quantity: $quantity, '
      'currentPeriodEnd: $currentPeriodEnd)';
}

/// A Stripe Subscription.
///
/// See https://stripe.com/docs/api/subscriptions/object.
final class Subscription {
  /// Creates a subscription directly from already-decoded fields.
  const Subscription({
    required this.id,
    this.status,
    this.customer,
    required this.items,
    this.latestInvoice,
    this.discounts = const [],
    this.currency,
    this.created,
    this.startDate,
    this.endedAt,
    this.canceledAt,
    this.cancelAt,
    this.cancelAtPeriodEnd,
    this.trialStart,
    this.trialEnd,
    this.trialPeriodDays,
    this.metadata = const {},
  });

  /// Decodes [json] into a [Subscription].
  factory Subscription.fromJson(Map<String, Object?> json) => Subscription(
        id: json.requireString('id', 'Subscription'),
        status: json.optString('status'),
        customer: switch (json['customer']) {
          null => null,
          final customerJson => Expandable<Customer>.fromJson(
              customerJson,
              Customer.fromJson,
              (customer) => customer.id,
              fieldName: 'subscription.customer',
            ),
        },
        items: StripeList<SubscriptionItem>.fromJson(
          json['items'],
          SubscriptionItem.fromJson,
        ),
        latestInvoice: switch (json['latest_invoice']) {
          null => null,
          final latestInvoiceJson => Expandable<Invoice>.fromJson(
              latestInvoiceJson,
              Invoice.fromJson,
              (invoice) => invoice.id,
              fieldName: 'subscription.latest_invoice',
            ),
        },
        discounts: json.optList<Expandable<Discount>>(
          'discounts',
          (element) => Expandable<Discount>.fromJson(
            element,
            Discount.fromJson,
            (discount) => discount.id,
            fieldName: 'subscription.discounts[]',
          ),
        ),
        currency: json.optString('currency'),
        created: json.optUnixTime('created'),
        startDate: json.optUnixTime('start_date'),
        endedAt: json.optUnixTime('ended_at'),
        canceledAt: json.optUnixTime('canceled_at'),
        cancelAt: json.optUnixTime('cancel_at'),
        cancelAtPeriodEnd: json.optBool('cancel_at_period_end'),
        trialStart: json.optUnixTime('trial_start'),
        trialEnd: json.optUnixTime('trial_end'),
        trialPeriodDays: json.optInt('trial_period_days'),
        metadata: json.optStringMap('metadata'),
      );

  /// The subscription's unique identifier.
  final String id;

  /// The status of this subscription: `'incomplete'`, `'trialing'`,
  /// `'active'`, `'past_due'`, `'canceled'`, `'unpaid'`, or `'paused'`.
  final String? status;

  /// The customer this subscription belongs to — either a bare id, or the
  /// expanded [Customer] when the request expanded `customer`.
  final Expandable<Customer>? customer;

  /// The individual items this subscription charges for.
  final StripeList<SubscriptionItem> items;

  /// The most recent invoice this subscription generated — either a bare
  /// id, or the expanded [Invoice] when the request expanded
  /// `latest_invoice`.
  final Expandable<Invoice>? latestInvoice;

  /// The discounts applied to this subscription — each either a bare id,
  /// or the expanded [Discount] when the request expanded `discounts`.
  final List<Expandable<Discount>> discounts;

  /// Three-letter ISO currency code, in lowercase.
  final String? currency;

  /// When this subscription was created.
  final DateTime? created;

  /// When this subscription's first billing cycle started.
  final DateTime? startDate;

  /// When this subscription ended, when it has.
  final DateTime? endedAt;

  /// When this subscription was canceled, when it was.
  final DateTime? canceledAt;

  /// When this subscription is scheduled to cancel, when it is scheduled
  /// to.
  final DateTime? cancelAt;

  /// Whether this subscription is scheduled to cancel at the end of its
  /// current billing period, rather than immediately.
  final bool? cancelAtPeriodEnd;

  /// When this subscription's trial period started, when it has one.
  final DateTime? trialStart;

  /// When this subscription's trial period ends, when it has one.
  final DateTime? trialEnd;

  /// The number of days the subscription's initial trial period lasts,
  /// when it was created with one.
  final int? trialPeriodDays;

  /// A set of key-value pairs Stripe attaches to the subscription.
  final Map<String, String> metadata;

  /// The start of the current billing period, read from this
  /// subscription's first item.
  ///
  /// Stripe removed `current_period_start` from the subscription object
  /// itself in API version `2025-03-31.basil`; it now lives only on each
  /// [SubscriptionItem]. This getter reads it off [items]`.data.first`,
  /// returning `null` when [items] is empty.
  ///
  /// A subscription whose items bill on different periods has no single
  /// period, and this getter does not represent one: read
  /// [SubscriptionItem.currentPeriodStart] per item instead.
  DateTime? get currentPeriodStart =>
      items.data.isEmpty ? null : items.data.first.currentPeriodStart;

  /// The end of the current billing period, read from this subscription's
  /// first item.
  ///
  /// See [currentPeriodStart] for why this reads [items] instead of a
  /// subscription-level field, and for the multi-item caveat.
  DateTime? get currentPeriodEnd =>
      items.data.isEmpty ? null : items.data.first.currentPeriodEnd;

  @override
  String toString() => 'Subscription(id: $id, status: $status)';
}

/// Parameters for listing Subscriptions.
///
/// See https://stripe.com/docs/api/subscriptions/list.
final class SubscriptionListParams {
  /// Creates the parameters, filtering by [customer] or [status] when
  /// given, capping the page at [limit], and requesting [expand] on each
  /// returned subscription.
  const SubscriptionListParams({
    this.customer,
    this.status,
    this.limit,
    this.expand,
  });

  /// Only return subscriptions belonging to this customer.
  final String? customer;

  /// Only return subscriptions with this status, or `'all'` to include
  /// every status.
  final String? status;

  /// A limit on the number of objects to return, between 1 and 100.
  final int? limit;

  /// The dotted field paths to expand on each returned subscription.
  final List<String>? expand;

  /// Encodes these parameters the way [SubscriptionsService.list] sends
  /// them.
  Map<String, Object?> toJson() => {
        if (customer != null) 'customer': customer,
        if (status != null) 'status': status,
        if (limit != null) 'limit': limit,
        if (expand != null) 'expand': expand,
      };

  @override
  String toString() => 'SubscriptionListParams(customer: $customer, '
      'status: $status)';
}

/// Subscription operations: `client.subscriptions.retrieve(id)`,
/// `client.subscriptions.list(...)`.
final class SubscriptionsService {
  /// Creates the service backed by [_client].
  SubscriptionsService(this._client);

  final StripeClient _client;

  /// Retrieves the subscription with the given [id].
  ///
  /// Pass `expand: ['latest_invoice']` in [params] to receive the full
  /// [Invoice] rather than just its id.
  Future<Subscription> retrieve(String id, [ExpandParams? params]) async {
    final json = await _client.request(
      method: 'GET',
      path: '/v1/subscriptions/$id',
      params: params?.toJson(),
    );
    return Subscription.fromJson(json as Map<String, Object?>);
  }

  /// Lists subscriptions, optionally filtered and paged by [params].
  Future<StripeList<Subscription>> list(
      [SubscriptionListParams? params]) async {
    final json = await _client.request(
      method: 'GET',
      path: '/v1/subscriptions',
      params: params?.toJson(),
    );
    return StripeList<Subscription>.fromJson(json, Subscription.fromJson);
  }
}
