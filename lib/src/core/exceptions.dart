/// Thrown when a Stripe API response body cannot be decoded into a typed
/// model.
///
/// This is distinct from the API error hierarchy in `errors.dart`, which
/// represents error responses *returned by* Stripe — a declined card, a rate
/// limit, an invalid request parameter. A [StripeDecodeException] means
/// Stripe answered successfully (a 2xx status) but the payload did not have
/// the shape this package expects of it, almost always because a field
/// changed shape between API versions. The two hierarchies are never mixed:
/// nothing in this file references `errors.dart`, and nothing there
/// references this file.
final class StripeDecodeException implements Exception {
  /// Creates a decode failure carrying [message] verbatim.
  ///
  /// Prefer the named constructors ([StripeDecodeException.missingRequiredKey],
  /// [StripeDecodeException.unexpectedType],
  /// [StripeDecodeException.invalidExpandable]) where one fits: they format a
  /// consistent message naming the object and field involved, which is the
  /// only context available once this exception surfaces in Sentry.
  StripeDecodeException(this.message);

  /// Creates the exception for [key] missing from — or `null` in — the JSON
  /// object for [objectName].
  ///
  /// Reserved for the small set of identifying fields (`id`, `object`) that
  /// every Stripe object is guaranteed to send. Every other field is read
  /// through the tolerant readers in `json_reading.dart`, which return
  /// `null` instead of throwing.
  StripeDecodeException.missingRequiredKey({
    required String objectName,
    required String key,
  }) : this('$objectName: required key "$key" is missing or null');

  /// Creates the exception for [key] present in the JSON object for
  /// [objectName], but holding a [value] of a type that could not be
  /// interpreted as the type [key] is expected to hold.
  StripeDecodeException.unexpectedType({
    required String objectName,
    required String key,
    required Object? value,
  }) : this(
          '$objectName: key "$key" has an unexpected type '
          '(${value.runtimeType}): ${_describe(value)}',
        );

  /// Creates the exception for an `Expandable` field whose raw JSON [value]
  /// was neither a `String` id nor a `Map<String, Object?>` object.
  ///
  /// [objectName] identifies the expandable's target type (for example
  /// `Invoice`), which is all the context available inside
  /// `Expandable.fromJson` — it has no visibility into which field of which
  /// enclosing object it was decoding.
  StripeDecodeException.invalidExpandable({
    required String objectName,
    required Object? value,
    String? fieldName,
  }) : this(
          'Expandable<$objectName>${fieldName == null ? '' : ' at $fieldName'}: '
          'expected a String id or a JSON object, '
          'got ${value.runtimeType}: ${_describe(value)}',
        );

  /// Creates the exception for an expanded object that carries no `id`.
  ///
  /// Every object Stripe lets you expand into is addressable, so one arriving
  /// without an id is malformed rather than merely unmodelled.
  StripeDecodeException.expandableWithoutId({
    required String objectName,
    String? fieldName,
  }) : this(
          'Expandable<$objectName>${fieldName == null ? '' : ' at $fieldName'}: '
          'the expanded object carries no "id"',
        );

  /// What went wrong, naming the object type and field involved.
  final String message;

  @override
  String toString() => 'StripeDecodeException: $message';
}

const int _maxDescriptionLength = 200;

String _describe(Object? value) {
  final text = '$value';
  return text.length > _maxDescriptionLength
      ? '${text.substring(0, _maxDescriptionLength)}…'
      : text;
}
