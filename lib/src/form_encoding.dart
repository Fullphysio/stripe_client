import 'dart:convert';

/// Encodes [data] the way `stripe-node` 19.3.1 encodes v1 request parameters.
///
/// This is a byte-for-byte port of stripe-node's `queryStringifyRequestData`,
/// which is a thin wrapper over the `qs` package's `qs.stringify` called with
/// `arrayFormat: 'indices'` (the only array format stripe-node uses for v1
/// requests) followed by unescaping `%5B`/`%5D` back to `[`/`]` in the whole
/// result. The returned string is used unchanged for both POST bodies and
/// GET/DELETE query strings.
///
/// Supported values, recursively, are [String], [num], [bool], [DateTime],
/// `null`, [List], and [Map] with [String] keys:
///
/// - Nested [Map]s produce bracketed keys: `{'a': {'b': 1}}` encodes as
///   `a[b]=1`.
/// - [List]s always use indices, matching stripe-node's v1 `arrayFormat`:
///   `{'a': [1, 2]}` encodes as `a[0]=1&a[1]=2`.
/// - Empty [List]s and empty [Map]s contribute no pairs, and that vanishing
///   cascades upward through every ancestor that becomes empty as a result:
///   `{'a': {'b': []}}` encodes as the empty string, not `a=`.
/// - A [DateTime] serialises as the floor of its epoch seconds (flooring
///   towards negative infinity, so a pre-1970 instant with a fractional
///   second rounds down, not towards zero).
/// - A key present with a `null` value serialises as `key=` (empty value); a
///   key absent from [data] contributes nothing. The two are not the same.
/// - A whole-valued [double] (e.g. `25.0`) encodes as `25`, matching
///   JavaScript's single numeric type.
/// - Percent-encoding is RFC 3986: the unreserved set is `A-Z a-z 0-9 - . _ ~`
///   only, applied to the UTF-8 bytes of every key and value, including the
///   brackets `qs` itself introduces for nesting — which is why the trailing
///   unescape step is a blind string replace rather than a structural one. A
///   literal `[` or `]` inside a value is therefore also unescaped by it, as
///   it is in stripe-node.
///
/// Throws an [ArgumentError] for any value that is not one of the supported
/// types above, for a non-[String] [Map] key, or for a non-finite [double].
///
/// Two behaviours diverge from stripe-node deliberately. Both are decided, not
/// oversights; do not "fix" either without changing this doc first.
///
/// - **Non-finite doubles throw.** JavaScript's `String(NaN)` yields `"NaN"`,
///   so stripe-node would put `amount=NaN` on the wire. A non-finite number
///   reaching a Stripe parameter is a caller bug, and surfacing it here is
///   worth more than byte-identical nonsense.
/// - **Key order is insertion order.** JavaScript's `Object.keys` returns
///   integer-like keys first, in ascending numeric order, before the rest in
///   insertion order — so `{'2': …, '1': …, 'x': …}` encodes as `1,2,x` under
///   stripe-node and as `2,1,x` here. This is reachable only through a
///   free-form map such as `metadata`, since no Stripe parameter name is a
///   bare number, and the order of distinct keys in a form-encoded body
///   carries no meaning to Stripe's parser. Emulating ECMAScript property
///   order would buy byte-equality with no behavioural difference.
String stripeFormEncode(Map<String, Object?> data) {
  final pairs = <String>[];
  for (final entry in data.entries) {
    pairs.addAll(_stringify(entry.value, entry.key));
  }
  return pairs.join('&').replaceAll('%5B', '[').replaceAll('%5D', ']');
}

List<String> _stringify(Object? value, String prefix) {
  if (value is DateTime) {
    return _leaf(prefix, _epochSecondsFloor(value).toString());
  }
  if (value == null) {
    return _leaf(prefix, '');
  }
  if (value is String) {
    return _leaf(prefix, value);
  }
  if (value is bool) {
    return _leaf(prefix, value.toString());
  }
  if (value is num) {
    return _leaf(prefix, _jsNumberToString(value, prefix));
  }
  if (value is List<Object?>) {
    final pairs = <String>[];
    for (var i = 0; i < value.length; i++) {
      pairs.addAll(_stringify(value[i], '$prefix[$i]'));
    }
    return pairs;
  }
  if (value is Map<String, Object?>) {
    final pairs = <String>[];
    for (final entry in value.entries) {
      pairs.addAll(_stringify(entry.value, '$prefix[${entry.key}]'));
    }
    return pairs;
  }
  throw ArgumentError(
    'stripeFormEncode: unsupported value type ${value.runtimeType} at "$prefix"',
  );
}

List<String> _leaf(String prefix, String value) {
  return ['${_percentEncode(prefix)}=${_percentEncode(value)}'];
}

int _epochSecondsFloor(DateTime date) {
  return (date.millisecondsSinceEpoch / 1000).floor();
}

String _jsNumberToString(num value, String prefix) {
  if (value is int) {
    return value.toString();
  }
  final doubleValue = value as double;
  if (doubleValue.isNaN || doubleValue.isInfinite) {
    throw ArgumentError(
      'stripeFormEncode: cannot encode a non-finite double at "$prefix"',
    );
  }
  if (doubleValue == 0) {
    return '0';
  }
  if (doubleValue == doubleValue.truncateToDouble()) {
    return doubleValue.toStringAsFixed(0);
  }
  return doubleValue.toString();
}

String _percentEncode(String value) {
  final buffer = StringBuffer();
  for (final byte in utf8.encode(value)) {
    if (_isUnreservedByte(byte)) {
      buffer.writeCharCode(byte);
    } else {
      buffer
        ..write('%')
        ..write(byte.toRadixString(16).toUpperCase().padLeft(2, '0'));
    }
  }
  return buffer.toString();
}

bool _isUnreservedByte(int byte) {
  return (byte >= 0x30 && byte <= 0x39) ||
      (byte >= 0x41 && byte <= 0x5A) ||
      (byte >= 0x61 && byte <= 0x7A) ||
      byte == 0x2D ||
      byte == 0x2E ||
      byte == 0x5F ||
      byte == 0x7E;
}
