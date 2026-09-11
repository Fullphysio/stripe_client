import 'exceptions.dart';

/// Tolerant readers for turning a decoded JSON object into typed Dart
/// values, used throughout the generated model code.
///
/// **Every reader here treats a missing key and a `null` value identically,
/// and returns `null` (or an empty collection) instead of throwing on either
/// one — regardless of what Stripe's OpenAPI spec's `required` or `nullable`
/// flags say about the field.** This is a deliberate, permanent choice, not
/// a gap to "fix" later. Two facts about Stripe's API make it necessary:
///
/// 1. `required` in Stripe's spec means "this key is present in the response
///    Stripe's own test suite produced," not "this value is guaranteed
///    non-null forever." Stripe documents fields as *both* `required` and
///    `nullable` in the same breath — `coupon.amount_off` is one example —
///    and the spec says nothing at all about a field a *future or past* API
///    version omits entirely.
/// 2. This package's direct predecessor, `client_stripe`, generated
///    `Subscription.currentPeriodStart` as a required, non-nullable `int`.
///    Stripe removed that exact field from the `Subscription` object in API
///    version `2025-03-31.basil`. Every decode of a subscription crashed.
///    That single crash is why this package exists — reproducing it here
///    would defeat the point.
///
/// This is not a relaxation of this repository's "fail loud" convention;
/// it is what applying that convention correctly looks like. Fail loud
/// protects invariants *this codebase* owns. The shape Stripe's API sends
/// on any given day is not one of them — a third-party API adding, removing,
/// or retyping a field is ordinary, expected drift, and silently tolerating
/// it here is what stops it from crashing every caller. [requireString] is
/// the one deliberate exception: `id` and `object` are identifying fields
/// so fundamental that a payload missing either is not "drift", it is not a
/// Stripe object at all.
extension StripeJsonReading on Map<String, Object?> {
  /// Reads [key] as a [String].
  ///
  /// Returns `null` if [key] is absent, its value is `null`, or its value is
  /// not a [String].
  String? optString(String key) {
    final value = this[key];
    return value is String ? value : null;
  }

  /// Reads [key] as an [int].
  ///
  /// Returns `null` if [key] is absent or its value is `null`. Stripe always
  /// sends whole numbers as JSON integers, but a value that has passed
  /// through an intermediate JSON encoder — a test fixture, a proxy, a
  /// webhook relay — can arrive as a [double] holding a whole value (`1.0`
  /// instead of `1`). This reader deliberately accepts that case and
  /// converts it, since JSON itself has only one numeric type and Dart's
  /// int/double split is `dart:convert`'s decoding choice, not a distinction
  /// Stripe's wire format makes. A [double] that is not finite, or that
  /// carries a genuine fractional part, is a real type mismatch rather than
  /// an encoding artifact, so it returns `null` instead of truncating.
  int? optInt(String key) {
    final value = this[key];
    if (value is int) {
      return value;
    }
    if (value is double && value.isFinite && value == value.roundToDouble()) {
      return value.toInt();
    }
    return null;
  }

  /// Reads [key] as a [double].
  ///
  /// Returns `null` if [key] is absent or its value is `null`. Accepts an
  /// [int] value and widens it, for the same reason [optInt] accepts a
  /// whole-valued [double]: JSON has one numeric type, and Stripe sending an
  /// integral value for a field this package models as a `double` is not a
  /// type error.
  double? optDouble(String key) {
    final value = this[key];
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    return null;
  }

  /// Reads [key] as a [bool].
  ///
  /// Returns `null` if [key] is absent, its value is `null`, or its value is
  /// not a [bool].
  bool? optBool(String key) {
    final value = this[key];
    return value is bool ? value : null;
  }

  /// Reads [key] as a Unix timestamp — an integer number of seconds since
  /// the epoch — and converts it to a UTC [DateTime].
  ///
  /// Returns `null` if [key] is absent or its value is `null`, and is
  /// tolerant of the same whole-valued-[double] drift as [optInt], since it
  /// is built on top of it. The result is always in UTC
  /// (`DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true)`),
  /// never the caller's local time zone — Stripe's timestamp is a point in
  /// time, not a wall-clock reading anywhere in particular.
  DateTime? optUnixTime(String key) {
    final seconds = optInt(key);
    if (seconds == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  /// Reads [key] as a `Map<String, String>`, the shape of Stripe's
  /// `metadata` field and every other free-form key/value field like it.
  ///
  /// Returns an empty map if [key] is absent, its value is `null`, or its
  /// value is not a JSON object — never `null` itself, so callers can index
  /// straight into the result without a null check. A non-string value
  /// under one of the map's own keys — which the documented shape of these
  /// fields does not allow, but which a hand-built fixture or an
  /// undocumented corner of the API could still send — is stringified with
  /// `Object.toString()` rather than dropped. Dropping it would make the key
  /// silently vanish, which is a worse surprise for a caller inspecting
  /// metadata than seeing an unexpected string representation of whatever
  /// was actually there; a `null` value under a key, in contrast, is
  /// dropped, consistent with every other reader here treating `null` as
  /// absence.
  Map<String, String> optStringMap(String key) {
    final value = this[key];
    if (value is! Map<String, Object?>) {
      return const <String, String>{};
    }
    final result = <String, String>{};
    for (final entry in value.entries) {
      final entryValue = entry.value;
      if (entryValue == null) {
        continue;
      }
      result[entry.key] =
          entryValue is String ? entryValue : entryValue.toString();
    }
    return result;
  }

  /// Reads [key] as a `List<R>`, applying [fromElement] to each raw element.
  ///
  /// Returns an empty list — never `null` — if [key] is absent, its value is
  /// `null`, or its value is not a JSON array, so callers can iterate the
  /// result unconditionally. [fromElement] receives each array element as
  /// the raw decoded JSON value and decides for itself how to interpret it;
  /// this reader does not inspect elements before passing them through.
  List<R> optList<R>(String key, R Function(Object? element) fromElement) {
    final value = this[key];
    if (value is! List<Object?>) {
      return <R>[];
    }
    return value.map(fromElement).toList(growable: false);
  }

  /// Reads [key] as a nested JSON object.
  ///
  /// Returns `null` if [key] is absent, its value is `null`, or its value is
  /// not a JSON object.
  Map<String, Object?>? optObject(String key) {
    final value = this[key];
    return value is Map<String, Object?> ? value : null;
  }

  /// Reads [key] as a nested JSON object and decodes it with [fromJson].
  ///
  /// Returns `null` if [key] is absent, its value is `null`, or its value is
  /// not a JSON object, without calling [fromJson] at all. If [fromJson]
  /// itself throws — for example because the nested object is missing its
  /// own required `id` — that exception propagates normally; this reader
  /// only shields callers from the *shape at this key* being wrong, not from
  /// [fromJson] rejecting the shape it did receive.
  R? optNested<R>(String key, R Function(Map<String, Object?>) fromJson) {
    final object = optObject(key);
    return object == null ? null : fromJson(object);
  }

  /// Reads [key], which must be present with a non-null [String] value.
  ///
  /// This is the one reader in this file that throws: it exists only for
  /// `id` and `object`, the two fields that identify what a Stripe object
  /// *is* rather than describing its current state. A payload missing
  /// either one is not ordinary field drift, it is not usable as the type
  /// [objectName] at all, so this throws a [StripeDecodeException] naming
  /// [objectName] and [key] rather than returning `null` for a caller to
  /// dereference later with no context.
  String requireString(String key, String objectName) {
    final value = this[key];
    if (value == null) {
      throw StripeDecodeException.missingRequiredKey(
        objectName: objectName,
        key: key,
      );
    }
    if (value is! String) {
      throw StripeDecodeException.unexpectedType(
        objectName: objectName,
        key: key,
        value: value,
      );
    }
    return value;
  }
}
