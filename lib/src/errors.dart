/// Base class for every error this package raises while talking to the
/// Stripe API.
///
/// Mirrors the class hierarchy of `stripe-node` 19.3.1's `Error.js`: a
/// sealed hierarchy of concrete subtypes instead of one class carrying a
/// `type` string discriminator, since Dart's type system already gives us
/// that for free. Use [stripeErrorFromResponse] to build the right subtype
/// from a v1 API response.
sealed class StripeError implements Exception {
  /// Creates a Stripe error carrying every field the raw payload provided.
  const StripeError({
    required this.message,
    this.type,
    this.code,
    this.docUrl,
    this.param,
    this.detail,
    this.charge,
    this.declineCode,
    this.paymentIntent,
    this.paymentMethod,
    this.paymentMethodType,
    this.setupIntent,
    this.source,
    this.userMessage,
    this.requestId,
    this.statusCode,
    this.headers,
    this.raw,
  });

  /// A human-readable message giving more details about the error. For
  /// card errors, this can be shown directly to end users.
  final String message;

  /// The Stripe error `type` string from the response body, for example
  /// `card_error` or `invalid_request_error`, or `null` when the response
  /// carried none.
  ///
  /// Corresponds to `rawType` in `stripe-node`. This package drops the
  /// redundant class-name string `stripe-node` itself calls `type`, since
  /// the concrete subtype already carries that information.
  final String? type;

  /// For card errors, a short string describing the kind of card error
  /// that occurred.
  ///
  /// See https://stripe.com/docs/error-codes.
  final String? code;

  /// A URL to more information about the error code reported.
  ///
  /// See https://stripe.com/docs/error-codes.
  final String? docUrl;

  /// The request parameter this error relates to, if it is parameter
  /// specific.
  final String? param;

  /// Additional detail carried by the raw error.
  ///
  /// `stripe-node` also reuses this field to carry the underlying
  /// transport failure on a connection error, so its shape is not fixed.
  final Object? detail;

  /// The charge this error relates to, when there is one.
  final String? charge;

  /// For card errors, a short string describing the bank's reason for
  /// declining the card.
  ///
  /// See https://stripe.com/docs/declines/codes.
  final String? declineCode;

  /// The raw PaymentIntent this error relates to, when there is one.
  final Object? paymentIntent;

  /// The raw PaymentMethod this error relates to, when there is one.
  final Object? paymentMethod;

  /// The type of the payment method this error relates to, when there is
  /// one.
  final String? paymentMethodType;

  /// The raw SetupIntent this error relates to, when there is one.
  final Object? setupIntent;

  /// The raw Source this error relates to, when there is one.
  final Object? source;

  /// A message Stripe marked safe to show to end users, when it provided
  /// one.
  final String? userMessage;

  /// The identifier of the request that produced this error, when known.
  final String? requestId;

  /// The HTTP status code of the response this error was built from, when
  /// it was built from one.
  final int? statusCode;

  /// The HTTP response headers this error was built from, when it was
  /// built from one.
  final Map<String, String>? headers;

  /// The raw payload this error was built from, exactly as received.
  ///
  /// Use this as an escape hatch for fields this class does not promote to
  /// a dedicated property.
  final Object? raw;

  @override
  String toString() => '$runtimeType: $message';
}

/// Raised when a customer's card can't be charged for some reason.
class StripeCardError extends StripeError {
  /// Creates a card error.
  const StripeCardError({
    required super.message,
    super.type,
    super.code,
    super.docUrl,
    super.param,
    super.detail,
    super.charge,
    super.declineCode,
    super.paymentIntent,
    super.paymentMethod,
    super.paymentMethodType,
    super.setupIntent,
    super.source,
    super.userMessage,
    super.requestId,
    super.statusCode,
    super.headers,
    super.raw,
  });
}

/// Raised when a request is initiated with invalid parameters.
class StripeInvalidRequestError extends StripeError {
  /// Creates an invalid-request error.
  const StripeInvalidRequestError({
    required super.message,
    super.type,
    super.code,
    super.docUrl,
    super.param,
    super.detail,
    super.charge,
    super.declineCode,
    super.paymentIntent,
    super.paymentMethod,
    super.paymentMethodType,
    super.setupIntent,
    super.source,
    super.userMessage,
    super.requestId,
    super.statusCode,
    super.headers,
    super.raw,
  });
}

/// A generic error that may be raised in cases where none of the other
/// named errors cover the problem.
///
/// Also raised for a response whose body could not be parsed as JSON at
/// all, and for a new error type introduced in the API that this version
/// of the package doesn't know how to handle either as a card, request,
/// authentication, permission, rate-limit, idempotency, or invalid-grant
/// error.
class StripeAPIError extends StripeError {
  /// Creates an API error.
  const StripeAPIError({
    required super.message,
    super.type,
    super.code,
    super.docUrl,
    super.param,
    super.detail,
    super.charge,
    super.declineCode,
    super.paymentIntent,
    super.paymentMethod,
    super.paymentMethodType,
    super.setupIntent,
    super.source,
    super.userMessage,
    super.requestId,
    super.statusCode,
    super.headers,
    super.raw,
  });
}

/// Raised when invalid credentials are used to connect to Stripe's
/// servers.
class StripeAuthenticationError extends StripeError {
  /// Creates an authentication error.
  const StripeAuthenticationError({
    required super.message,
    super.type,
    super.code,
    super.docUrl,
    super.param,
    super.detail,
    super.charge,
    super.declineCode,
    super.paymentIntent,
    super.paymentMethod,
    super.paymentMethodType,
    super.setupIntent,
    super.source,
    super.userMessage,
    super.requestId,
    super.statusCode,
    super.headers,
    super.raw,
  });
}

/// Raised when access was attempted on a resource that wasn't allowed.
class StripePermissionError extends StripeError {
  /// Creates a permission error.
  const StripePermissionError({
    required super.message,
    super.type,
    super.code,
    super.docUrl,
    super.param,
    super.detail,
    super.charge,
    super.declineCode,
    super.paymentIntent,
    super.paymentMethod,
    super.paymentMethodType,
    super.setupIntent,
    super.source,
    super.userMessage,
    super.requestId,
    super.statusCode,
    super.headers,
    super.raw,
  });
}

/// Raised when an account is putting too much load on Stripe's API
/// servers, usually by performing too many requests. Back off on request
/// rate.
class StripeRateLimitError extends StripeError {
  /// Creates a rate-limit error.
  const StripeRateLimitError({
    required super.message,
    super.type,
    super.code,
    super.docUrl,
    super.param,
    super.detail,
    super.charge,
    super.declineCode,
    super.paymentIntent,
    super.paymentMethod,
    super.paymentMethodType,
    super.setupIntent,
    super.source,
    super.userMessage,
    super.requestId,
    super.statusCode,
    super.headers,
    super.raw,
  });
}

/// Raised when the HTTP transport could not reach Stripe at all: DNS
/// failure, connection reset, TLS error, or a timeout.
///
/// Unlike every other subtype, this one is never produced by
/// [stripeErrorFromResponse] -- there is no HTTP response to dispatch on.
/// The transport layer constructs it directly when a request attempt never
/// produces a response.
class StripeConnectionError extends StripeError {
  /// Creates a connection failure carrying [message], optionally wrapping
  /// the transport-level [cause].
  const StripeConnectionError(String message, {Object? cause})
      : super(message: message, detail: cause);
}

/// Raised when an idempotency key was used improperly: reused on a request
/// that does not match the first request's endpoint and parameters.
class StripeIdempotencyError extends StripeError {
  /// Creates an idempotency error.
  const StripeIdempotencyError({
    required super.message,
    super.type,
    super.code,
    super.docUrl,
    super.param,
    super.detail,
    super.charge,
    super.declineCode,
    super.paymentIntent,
    super.paymentMethod,
    super.paymentMethodType,
    super.setupIntent,
    super.source,
    super.userMessage,
    super.requestId,
    super.statusCode,
    super.headers,
    super.raw,
  });
}

/// Raised when a specified authorization code doesn't exist, is expired,
/// has been used, or doesn't belong to you; a refresh token doesn't exist
/// or doesn't belong to you; or an API key's mode (live or test) doesn't
/// match the mode of a code or refresh token.
class StripeInvalidGrantError extends StripeError {
  /// Creates an invalid-grant error.
  const StripeInvalidGrantError({
    required super.message,
    super.type,
    super.code,
    super.docUrl,
    super.param,
    super.detail,
    super.charge,
    super.declineCode,
    super.paymentIntent,
    super.paymentMethod,
    super.paymentMethodType,
    super.setupIntent,
    super.source,
    super.userMessage,
    super.requestId,
    super.statusCode,
    super.headers,
    super.raw,
  });
}

/// Raised when a webhook payload's signature cannot be verified against the
/// endpoint secret.
///
/// Carries the offending [header] and [payload] so a handler can log what
/// arrived. Never log the endpoint secret alongside them.
///
/// Declared here rather than beside the webhook code because [StripeError] is
/// `sealed`, which confines its subtypes to this library.
class StripeSignatureVerificationError extends StripeError {
  /// Creates a signature verification failure for [header] over [payload].
  const StripeSignatureVerificationError({
    required super.message,
    required this.header,
    required this.payload,
  });

  /// The raw `Stripe-Signature` header that failed verification, or null when
  /// the request carried none.
  final String? header;

  /// The raw request body the signature was checked against.
  final String? payload;
}

/// Any other error from Stripe not specifically captured above: the
/// fallback for a `type` string this package does not recognise.
class StripeUnknownError extends StripeError {
  /// Creates an unknown error.
  const StripeUnknownError({
    required super.message,
    super.type,
    super.code,
    super.docUrl,
    super.param,
    super.detail,
    super.charge,
    super.declineCode,
    super.paymentIntent,
    super.paymentMethod,
    super.paymentMethodType,
    super.setupIntent,
    super.source,
    super.userMessage,
    super.requestId,
    super.statusCode,
    super.headers,
    super.raw,
  });
}

/// Builds the [StripeError] subtype for a v1 API response, reproducing the
/// dispatch order of `stripe-node`'s `RequestSender._jsonResponseHandler`
/// exactly.
///
/// `stripe-node` checks the HTTP [statusCode] *before* it ever looks at the
/// body's `type` string: a 401 always becomes [StripeAuthenticationError],
/// a 403 always becomes [StripePermissionError], and a 429 always becomes
/// [StripeRateLimitError], regardless of what [rawError]'s `type` field
/// says. Only once none of those three statuses match does the `type`
/// string get to pick the subtype (`generateV1Error` in `Error.js`),
/// falling back to [StripeUnknownError] for a `type` this package does not
/// recognise.
///
/// [rawError] is the decoded `error` object from the response body: a
/// `Map<String, Object?>` for a normal Stripe error, a bare `String` for
/// the flat OAuth-style error shape (`{"error": "invalid_grant", ...}`),
/// or `null` when the body could not be decoded at all -- an empty body, a
/// non-JSON body, or a body with no `error` key. `stripe-node` treats that
/// last case as a successful, error-free response; this package cannot,
/// since it is only ever called once the caller already knows the
/// response failed (typically from a non-2xx [statusCode]), so a `null`
/// always produces a [StripeAPIError] carrying the same `'Invalid JSON
/// received from the Stripe API'` message `stripe-node` uses for an
/// undecodable body -- and, matching `stripe-node`, that fallback leaves
/// [StripeError.statusCode] and [StripeError.headers] unset even though
/// both are available here.
StripeError stripeErrorFromResponse({
  required int statusCode,
  required Object? rawError,
  required Map<String, String> headers,
  String? requestId,
}) {
  final fields = _parseFields(
    rawError,
    headers: headers,
    statusCode: statusCode,
    requestId: requestId,
  );
  if (fields == null) {
    return StripeAPIError(
      message: 'Invalid JSON received from the Stripe API',
      requestId: requestId,
      raw: {
        'message': 'Invalid JSON received from the Stripe API',
        'requestId': requestId,
      },
    );
  }
  if (statusCode == 401) return _build(StripeAuthenticationError.new, fields);
  if (statusCode == 403) return _build(StripePermissionError.new, fields);
  if (statusCode == 429) return _build(StripeRateLimitError.new, fields);
  return switch (fields.type) {
    'card_error' => _build(StripeCardError.new, fields),
    'invalid_request_error' => _build(StripeInvalidRequestError.new, fields),
    'api_error' => _build(StripeAPIError.new, fields),
    'authentication_error' => _build(StripeAuthenticationError.new, fields),
    'rate_limit_error' => _build(StripeRateLimitError.new, fields),
    'idempotency_error' => _build(StripeIdempotencyError.new, fields),
    'invalid_grant' => _build(StripeInvalidGrantError.new, fields),
    _ => _build(StripeUnknownError.new, fields),
  };
}

typedef _ErrorFields = ({
  String message,
  String? type,
  String? code,
  String? docUrl,
  String? param,
  Object? detail,
  String? charge,
  String? declineCode,
  Object? paymentIntent,
  Object? paymentMethod,
  String? paymentMethodType,
  Object? setupIntent,
  Object? source,
  String? userMessage,
  String? requestId,
  int? statusCode,
  Map<String, String>? headers,
  Object? raw,
});

typedef _ErrorConstructor = StripeError Function({
  required String message,
  String? type,
  String? code,
  String? docUrl,
  String? param,
  Object? detail,
  String? charge,
  String? declineCode,
  Object? paymentIntent,
  Object? paymentMethod,
  String? paymentMethodType,
  Object? setupIntent,
  Object? source,
  String? userMessage,
  String? requestId,
  int? statusCode,
  Map<String, String>? headers,
  Object? raw,
});

StripeError _build(_ErrorConstructor constructor, _ErrorFields fields) =>
    constructor(
      message: fields.message,
      type: fields.type,
      code: fields.code,
      docUrl: fields.docUrl,
      param: fields.param,
      detail: fields.detail,
      charge: fields.charge,
      declineCode: fields.declineCode,
      paymentIntent: fields.paymentIntent,
      paymentMethod: fields.paymentMethod,
      paymentMethodType: fields.paymentMethodType,
      setupIntent: fields.setupIntent,
      source: fields.source,
      userMessage: fields.userMessage,
      requestId: fields.requestId,
      statusCode: fields.statusCode,
      headers: fields.headers,
      raw: fields.raw,
    );

_ErrorFields? _parseFields(
  Object? rawError, {
  required Map<String, String> headers,
  required int statusCode,
  required String? requestId,
}) {
  if (rawError == null) return null;
  final Map<String, Object?> decoded = switch (rawError) {
    final String type => {'type': type},
    final Map<String, Object?> value => value,
    _ => throw ArgumentError.value(
        rawError,
        'rawError',
        'must be a Map<String, Object?>, a String, or null',
      ),
  };
  final Map<String, Object?> raw = {
    ...decoded,
    'headers': headers,
    'statusCode': statusCode,
    'requestId': requestId,
  };
  return (
    message: raw['message'] as String? ?? '',
    type: raw['type'] as String?,
    code: raw['code'] as String?,
    docUrl: raw['doc_url'] as String?,
    param: raw['param'] as String?,
    detail: raw['detail'],
    charge: raw['charge'] as String?,
    declineCode: raw['decline_code'] as String?,
    paymentIntent: raw['payment_intent'],
    paymentMethod: raw['payment_method'],
    paymentMethodType: raw['payment_method_type'] as String?,
    setupIntent: raw['setup_intent'],
    source: raw['source'],
    userMessage: raw['user_message'] as String?,
    requestId: requestId,
    statusCode: statusCode,
    headers: headers,
    raw: raw,
  );
}
