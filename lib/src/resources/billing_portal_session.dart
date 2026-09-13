import '../core/json_reading.dart';
import '../transport/stripe_client.dart';

/// Parameters for creating a Billing Portal session.
///
/// See https://stripe.com/docs/api/customer_portal/sessions/create.
final class BillingPortalSessionCreateParams {
  /// Creates the parameters for a Billing Portal session for [customer],
  /// which redirects back to [returnUrl] once the customer is done managing
  /// their billing.
  const BillingPortalSessionCreateParams({
    required this.customer,
    required this.returnUrl,
  });

  /// The ID of an existing customer.
  final String customer;

  /// The default URL to redirect the customer to after they log out of the
  /// portal.
  final String returnUrl;

  /// Encodes these parameters the way
  /// [BillingPortalSessionsService.create] sends them.
  Map<String, Object?> toJson() => {
        'customer': customer,
        'return_url': returnUrl,
      };

  @override
  String toString() => 'BillingPortalSessionCreateParams(customer: $customer, '
      'returnUrl: $returnUrl)';
}

/// A Billing Portal session: a short-lived, single-use link a customer
/// follows to manage their own billing.
///
/// See https://stripe.com/docs/api/customer_portal/sessions/object.
final class BillingPortalSession {
  /// Creates a session directly from already-decoded fields.
  const BillingPortalSession({required this.id, this.url});

  /// Decodes [json] into a [BillingPortalSession].
  factory BillingPortalSession.fromJson(Map<String, Object?> json) =>
      BillingPortalSession(
        id: json.requireString('id', 'BillingPortalSession'),
        url: json.optString('url'),
      );

  /// The session's unique identifier.
  final String id;

  /// The URL the customer should be redirected to in order to manage their
  /// billing, when Stripe sent one.
  final String? url;

  @override
  String toString() => 'BillingPortalSession(id: $id, url: $url)';
}

/// Billing Portal Session operations:
/// `client.billingPortal.sessions.create(...)`.
final class BillingPortalSessionsService {
  /// Creates the service backed by [_client].
  BillingPortalSessionsService(this._client);

  final StripeClient _client;

  /// Creates a Billing Portal session for the customer and return URL given
  /// in [params].
  ///
  /// [idempotencyKey] overrides the automatically generated key that makes
  /// retries of this call safe; see [StripeClient.request].
  Future<BillingPortalSession> create(
    BillingPortalSessionCreateParams params, {
    String? idempotencyKey,
  }) async {
    final json = await _client.request(
      method: 'POST',
      path: '/v1/billing_portal/sessions',
      params: params.toJson(),
      idempotencyKey: idempotencyKey,
    );
    return BillingPortalSession.fromJson(json as Map<String, Object?>);
  }
}
