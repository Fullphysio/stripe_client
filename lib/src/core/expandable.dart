import 'package:meta/meta.dart';

import 'exceptions.dart';
import 'json_reading.dart';

/// A Stripe field that is either a bare object id, or the full object when
/// the request expanded it.
///
/// Many Stripe fields — `subscription.latestInvoice`, `invoice.customer`,
/// `charge.paymentIntent`, and dozens more — are polymorphic: ordinarily
/// just the referenced object's id (a `String`), but the full object when
/// the caller passed the field's dotted path to the request's `expand`
/// parameter. The reference implementation, `stripe-node`, discriminates
/// the two with a single `typeof x === "string"` check.
///
/// This is a plain generic class, not a `sealed` one. That is a deliberate
/// choice: real call sites overwhelmingly want [id] — always available,
/// expanded or not — or a null check on [value]. Forcing an exhaustive
/// `switch` at every read site, as a sealed hierarchy would, is ceremony the
/// reference implementation never needed.
///
/// This type does not model absence. A field typed `Expandable<Invoice>?`
/// in generated code means "the field may be absent (`null`), or present as
/// either an id or an expanded object" — the nullability belongs to the
/// generated field, not to this class. Nothing here ever swallows a JSON
/// `null`: it reaches [Expandable.fromJson] only if a caller passes it in,
/// and that throws, so generated `fromJson` code is expected to check for
/// `null` itself before calling in.
@immutable
final class Expandable<T> {
  /// Creates an unexpanded reference, known only by its [id].
  const Expandable.id(this.id) : value = null;

  /// Creates an expanded reference, carrying both the [id] and the full
  /// [value] the request expanded it into.
  const Expandable.expanded(this.id, T this.value);

  /// Parses [json] as either a bare id string or an expanded object.
  ///
  /// - A [String] becomes an unexpanded [Expandable.id].
  /// - A `Map<String, Object?>` is decoded with [fromJson], and its id is
  ///   read back out with [idOf] to populate [Expandable.expanded]'s [id] —
  ///   so [id] is always available without re-parsing [value].
  /// - Anything else — including `null` — throws [StripeDecodeException].
  ///   A caller with a nullable expandable field must check for `null`
  ///   before calling this factory; unlike the readers in `json_reading.dart`,
  ///   this constructor never treats absence as a valid encoding of itself.
  /// Pass [fieldName] — the owning field's dotted path, such as
  /// `subscription.latest_invoice` — so a failure names the field rather than
  /// only its type. Generated code always supplies it; a decode failure that
  /// reaches Sentry has no other context to identify which of an object's
  /// several `Expandable<Invoice>` fields was malformed.
  factory Expandable.fromJson(
    Object? json,
    T Function(Map<String, Object?>) fromJson,
    String Function(T) idOf, {
    String? fieldName,
  }) {
    if (json is String) {
      return Expandable<T>.id(json);
    }
    if (json is Map<String, Object?>) {
      final value = fromJson(json);
      return Expandable<T>.expanded(idOf(value), value);
    }
    throw StripeDecodeException.invalidExpandable(
      objectName: T.toString(),
      value: json,
      fieldName: fieldName,
    );
  }

  /// The referenced object's id — always available, whether or not this
  /// field was expanded.
  final String id;

  /// The full object, when the request expanded this field; `null`
  /// otherwise.
  final T? value;

  /// Whether the request expanded this field into the full [value].
  bool get isExpanded => value != null;

  /// Encodes this reference back to JSON, the way Stripe represents it on
  /// the wire: the bare [id] when unexpanded, or [valueToJson] applied to
  /// [value] when expanded.
  Object? toJson(Object? Function(T) valueToJson) {
    final currentValue = value;
    return currentValue == null ? id : valueToJson(currentValue);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Expandable<T> && other.id == id && other.value == value);

  @override
  int get hashCode => Object.hash(id, value);

  @override
  String toString() => isExpanded
      ? 'Expandable<$T>.expanded(id: $id, value: $value)'
      : 'Expandable<$T>.id($id)';
}

/// A minimal placeholder for a Stripe object this package does not model.
///
/// The code generator only emits typed models for the Stripe products this
/// package targets, following an explicit allowlist. A field that
/// references another product — a Connect account, a dispute, a legacy
/// source, and similar — would otherwise have nowhere to deserialize into.
/// Such fields are generated as `Expandable<StripeStub>` instead of being
/// dropped, so the reference stays identifiable and loggable: [id] and
/// [object] surface the two fields present on every Stripe object, and
/// [raw] keeps the entire decoded JSON in case a caller needs a field this
/// stub does not surface.
///
/// Equality and `hashCode` compare only [id] and [object]; [raw] is an
/// unstructured bag of whatever fields Stripe happened to send and is
/// deliberately excluded, so two stubs decoded from logically the same
/// object stay equal even if Stripe adds a field to it between calls.
@immutable
final class StripeStub {
  /// Creates a stub directly from already-decoded fields.
  const StripeStub({required this.id, required this.object, required this.raw});

  /// Decodes [json] into a stub, reading [id] and [object] out of it and
  /// keeping the whole map as [raw].
  ///
  /// Never throws: an unmodeled object's shape is by definition unknown to
  /// this package, so even a missing `id` or `object` merely leaves that
  /// field `null` rather than being treated as malformed.
  factory StripeStub.fromJson(Map<String, Object?> json) => StripeStub(
        id: json.optString('id'),
        object: json.optString('object'),
        raw: json,
      );

  /// Reads [stub]'s id for use as an [Expandable]'s id.
  ///
  /// Exists because [id] is nullable — an unmodelled object's shape is not
  /// guaranteed — while [Expandable] requires a non-null id. Generated code
  /// passes this as `idOf` for every `Expandable<StripeStub>` field, so the
  /// malformed case throws with a useful message instead of being papered
  /// over with an empty string at each call site.
  static String idOf(StripeStub stub, {String? fieldName}) =>
      stub.id ??
      (throw StripeDecodeException.expandableWithoutId(
        objectName: 'StripeStub',
        fieldName: fieldName,
      ));

  /// The object's id, when present.
  final String? id;

  /// The object's `object` discriminator string (for example `"account"`),
  /// when present.
  final String? object;

  /// The complete decoded JSON for this object, for callers that need a
  /// field this stub does not surface.
  final Map<String, Object?> raw;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StripeStub && other.id == id && other.object == object);

  @override
  int get hashCode => Object.hash(id, object);

  @override
  String toString() => 'StripeStub(id: $id, object: $object)';
}
