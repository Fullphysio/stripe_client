import 'package:meta/meta.dart';

import 'exceptions.dart';
import 'json_reading.dart';

/// Stripe's list wrapper: the same shape everywhere an endpoint returns more
/// than one object — `subscription.items`, `invoice.lines`, and every
/// top-level list endpoint such as `GET /v1/customers`.
///
/// This one generic class is emitted for every such field; there is no
/// per-resource list type generated. Iterating every page of a paginated
/// list is a different concern, handled by the auto-pagination helpers in
/// `pagination.dart` — this class only holds the single page of [data] a
/// response actually carried.
///
/// Decoding is tolerant of the same drift as every reader in
/// `json_reading.dart`: [StripeList.fromJson] accepts a `json` that is
/// entirely absent (not a JSON object at all) and returns an empty list
/// rather than throwing, and a missing `has_more` defaults to `false`. A
/// list-shaped field is either present with its normal shape or missing
/// altogether in practice — unlike [Expandable], there is no "invalid but
/// clearly present" middle case worth failing loudly over.
@immutable
final class StripeList<T> {
  /// Creates a list wrapper directly from already-decoded values.
  const StripeList({this.data = const [], required this.hasMore, this.url});

  /// Decodes [json] as a Stripe list object, applying [fromJson] to each
  /// element of its `data` array.
  ///
  /// Returns an empty, `hasMore: false` list if [json] is `null` or not a
  /// JSON object at all. Within a well-formed object, `data` defaults to an
  /// empty list and `has_more` defaults to `false` when either is missing.
  /// An element of `data` that is not itself a JSON object throws a
  /// [StripeDecodeException] — unlike a missing field, a list whose items
  /// are not objects is not API-version drift, it is a broken invariant of
  /// the list shape itself.
  factory StripeList.fromJson(
    Object? json,
    T Function(Map<String, Object?>) fromJson,
  ) {
    if (json is! Map<String, Object?>) {
      return StripeList<T>(hasMore: false);
    }
    return StripeList<T>(
      data: json.optList<T>('data', (element) {
        if (element is! Map<String, Object?>) {
          throw StripeDecodeException.unexpectedType(
            objectName: 'StripeList<$T>',
            key: 'data[]',
            value: element,
          );
        }
        return fromJson(element);
      }),
      hasMore: json.optBool('has_more') ?? false,
      url: json.optString('url'),
    );
  }

  /// The page of objects this response carried.
  final List<T> data;

  /// Whether Stripe has more objects beyond this page, for the same query.
  final bool hasMore;

  /// The list endpoint's own URL, when Stripe sent one.
  final String? url;

  @override
  String toString() =>
      'StripeList<$T>(data: $data, hasMore: $hasMore, url: $url)';
}
