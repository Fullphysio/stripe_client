import 'dart:convert';

import 'package:http/http.dart' as http;

import '../crypto_util.dart';
import '../errors.dart';
import '../form_encoding.dart';
import '../resources/billing_portal_session.dart';
import '../resources/checkout_session.dart';
import '../resources/customer.dart';
import '../resources/invoice.dart';
import '../resources/price.dart';
import '../resources/product.dart';
import '../resources/promotion_code.dart';
import '../resources/subscription.dart';
import 'retry_policy.dart';

const String _stripeApiVersion = '2025-11-17.clover';

/// A client for the Stripe API.
///
/// Wires HTTP transport — retries, idempotency keys, error mapping — to the
/// typed resources reachable through fields such as [billingPortal]. One
/// instance should be reused for the lifetime of the process it runs in;
/// call [close] once it is no longer needed.
///
/// ```dart
/// final stripe = StripeClient(apiKey: Platform.environment['STRIPE_API_KEY']!);
/// final session = await stripe.billingPortal.sessions.create(
///   BillingPortalSessionCreateParams(customer: customerId, returnUrl: returnUrl),
/// );
/// ```
final class StripeClient {
  /// Creates a client authenticated with [apiKey].
  ///
  /// [baseUrl] overrides the API origin — for tests, or for `stripe-mock` —
  /// and defaults to `https://api.stripe.com`. [httpClient] is an injection
  /// seam for tests; when omitted, a fresh [http.Client] is created and
  /// owned by this instance, to be closed by [close]. [maxNetworkRetries],
  /// [initialNetworkRetryDelay], [maxNetworkRetryDelay] and
  /// [maxRetryAfterWait] configure the retry policy applied to every
  /// request; see [request].
  StripeClient({
    required String apiKey,
    Uri? baseUrl,
    http.Client? httpClient,
    this.maxNetworkRetries = 2,
    this.initialNetworkRetryDelay = const Duration(milliseconds: 500),
    this.maxNetworkRetryDelay = const Duration(seconds: 5),
    this.maxRetryAfterWait = const Duration(seconds: 60),
  })  : _apiKey = apiKey,
        _baseUrl = baseUrl ?? Uri.parse('https://api.stripe.com'),
        _httpClient = httpClient ?? http.Client(),
        _ownsHttpClient = httpClient == null {
    billingPortal = BillingPortalNamespace(this);
    checkout = CheckoutNamespace(this);
  }

  final String _apiKey;
  final Uri _baseUrl;
  final http.Client _httpClient;
  final bool _ownsHttpClient;

  /// How many times a failed request is retried, on top of the initial
  /// attempt, before the failure is thrown.
  final int maxNetworkRetries;

  /// The delay before the first retry, doubled for every subsequent one and
  /// capped at [maxNetworkRetryDelay].
  final Duration initialNetworkRetryDelay;

  /// The upper bound on the exponential backoff delay between retries.
  final Duration maxNetworkRetryDelay;

  /// The upper bound honoured for a `Retry-After` value Stripe sends on a
  /// response, in place of the exponential backoff.
  final Duration maxRetryAfterWait;

  /// Billing Portal resources: `client.billingPortal.sessions.create(...)`.
  late final BillingPortalNamespace billingPortal;

  /// Checkout resources: `client.checkout.sessions.create(...)`.
  late final CheckoutNamespace checkout;

  /// Customer operations: `client.customers.retrieve(id)`.
  late final CustomersService customers = CustomersService(this);

  /// Promotion Code operations: `client.promotionCodes.create(...)`.
  late final PromotionCodesService promotionCodes = PromotionCodesService(this);

  /// Subscription operations: `client.subscriptions.retrieve(id)`.
  late final SubscriptionsService subscriptions = SubscriptionsService(this);

  /// Invoice operations: `client.invoices.retrieve(id)`.
  late final InvoicesService invoices = InvoicesService(this);

  /// Price operations: `client.prices.retrieve(id)`.
  late final PricesService prices = PricesService(this);

  /// Product operations: `client.products.retrieve(id)`.
  late final ProductsService products = ProductsService(this);

  /// Sends one Stripe API request and returns its decoded JSON body.
  ///
  /// [method] is `'GET'`, `'POST'`, or `'DELETE'`. [path] is the request
  /// path, including the leading `/v1/...`. [params] are form-encoded onto
  /// the query string for `GET`/`DELETE`, or onto the request body for
  /// `POST`.
  ///
  /// A `POST` carries an `Idempotency-Key` header, so a retry never
  /// double-applies it: [idempotencyKey] is used if given, otherwise one is
  /// generated once for this call and reused on every attempt.
  ///
  /// A failed attempt is retried according to [maxNetworkRetries] and the
  /// rest of this client's retry configuration. Returns the decoded response
  /// body — typically a `Map<String, Object?>`, or `null` for an empty body
  /// — on a 2xx response. Once retries are exhausted or the response is not
  /// retryable, throws the [StripeError] subtype [stripeErrorFromResponse]
  /// builds for a non-2xx response, or a [StripeConnectionError] if no
  /// response was ever received.
  Future<Object?> request({
    required String method,
    required String path,
    Map<String, Object?>? params,
    String? idempotencyKey,
  }) async {
    final hasBody = method == 'POST';
    final resolvedIdempotencyKey =
        hasBody ? (idempotencyKey ?? stripeUuidV4()) : null;
    final effectiveParams = params ?? const <String, Object?>{};

    var attempt = 0;
    while (true) {
      http.Response? response;
      Object? connectionError;
      try {
        response = await _send(
          method: method,
          path: path,
          params: effectiveParams,
          hasBody: hasBody,
          idempotencyKey: resolvedIdempotencyKey,
        );
      } on Exception catch (error) {
        connectionError = error;
      }

      if (response != null &&
          response.statusCode >= 200 &&
          response.statusCode < 300) {
        return response.body.isEmpty ? null : jsonDecode(response.body);
      }

      if (!stripeShouldRetry(
        attempt: attempt,
        maxNetworkRetries: maxNetworkRetries,
        response: response,
      )) {
        if (response == null) {
          throw StripeConnectionError(
            'An error occurred with our connection to Stripe.',
            cause: connectionError,
          );
        }
        throw _errorFromResponse(response);
      }

      await Future<void>.delayed(stripeRetryDelay(
        attempt: attempt,
        initialDelay: initialNetworkRetryDelay,
        maxDelay: maxNetworkRetryDelay,
        retryAfter: _retryAfter(response),
        maxRetryAfterWait: maxRetryAfterWait,
      ));
      attempt++;
    }
  }

  Future<http.Response> _send({
    required String method,
    required String path,
    required Map<String, Object?> params,
    required bool hasBody,
    required String? idempotencyKey,
  }) async {
    final encoded = stripeFormEncode(params);
    final uri = hasBody
        ? _baseUrl.replace(path: path)
        : _baseUrl.replace(path: path, query: encoded.isEmpty ? null : encoded);

    final request = http.Request(method, uri)
      ..headers['Authorization'] = 'Bearer $_apiKey'
      ..headers['Content-Type'] = 'application/x-www-form-urlencoded'
      ..headers['Stripe-Version'] = _stripeApiVersion;

    if (hasBody) {
      request.body = encoded;
      if (idempotencyKey != null) {
        request.headers['Idempotency-Key'] = idempotencyKey;
      }
    } else {
      request.headers['Content-Length'] = '0';
    }

    final streamed = await _httpClient.send(request);
    return http.Response.fromStream(streamed);
  }

  /// Closes the underlying HTTP client, if this instance created it.
  ///
  /// Does nothing when this client was constructed with a caller-supplied
  /// `httpClient`, since that client's lifetime belongs to its caller.
  void close() {
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }
}

/// Billing Portal resources: currently just
/// [BillingPortalNamespace.sessions].
final class BillingPortalNamespace {
  /// Creates the namespace backed by [_client].
  BillingPortalNamespace(this._client);

  final StripeClient _client;

  /// Billing Portal Session operations.
  late final BillingPortalSessionsService sessions =
      BillingPortalSessionsService(_client);
}

/// Checkout resources: currently just [CheckoutNamespace.sessions].
final class CheckoutNamespace {
  /// Creates the namespace backed by [_client].
  CheckoutNamespace(this._client);

  final StripeClient _client;

  /// Checkout Session operations.
  late final CheckoutSessionsService sessions =
      CheckoutSessionsService(_client);
}

StripeError _errorFromResponse(http.Response response) {
  final decoded = _decodeBody(response.body);
  final rawError = decoded is Map<String, Object?> ? decoded['error'] : null;
  return stripeErrorFromResponse(
    statusCode: response.statusCode,
    rawError: rawError,
    headers: response.headers,
    requestId: response.headers['request-id'],
  );
}

Object? _decodeBody(String body) {
  if (body.isEmpty) {
    return null;
  }
  try {
    return jsonDecode(body);
  } on FormatException {
    return null;
  }
}

Duration? _retryAfter(http.Response? response) {
  final value = response?.headers['retry-after'];
  if (value == null) {
    return null;
  }
  final seconds = int.tryParse(value);
  return seconds == null ? null : Duration(seconds: seconds);
}
