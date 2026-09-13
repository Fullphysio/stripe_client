import 'dart:convert';

import 'crypto_util.dart';
import 'errors.dart';
import 'resources/event.dart';

/// Verifies and decodes a Stripe webhook delivery.
///
/// Reproduces `stripe-node` 19.3.1's `Webhook.constructEvent` /
/// `signature.verifyHeader`: parse the `Stripe-Signature` header, recompute
/// the HMAC over the exact request body, compare in constant time, and only
/// then parse the body as JSON.
final class StripeWebhooks {
  const StripeWebhooks._();

  /// Verifies [payload] against [header] using the webhook endpoint's
  /// [secret], and decodes it into an [Event].
  ///
  /// [payload] is the *exact* request body Stripe sent: a [String], or the
  /// raw [List<int>] bytes read straight off the wire. Prefer the byte form
  /// when available — decoding a request body to [String] before it reaches
  /// this function risks corrupting bytes that are not valid UTF-8, which
  /// would make the signature this function recomputes not match the one
  /// Stripe sent, even for a genuine delivery.
  ///
  /// [header] is the raw `Stripe-Signature` header value, shaped
  /// `t=<unix-timestamp>,v1=<hex-signature>[,v1=<hex-signature>][,v0=...]`.
  /// Multiple `v1` entries can appear during secret rotation; this method
  /// accepts the payload if *any* `v1` signature matches. `v0` entries are
  /// ignored — they exist for backward compatibility with a signature
  /// scheme this package does not implement.
  ///
  /// [tolerance] bounds how old the header's timestamp may be, in seconds,
  /// compared to now. Passing `tolerance <= 0` disables that check entirely,
  /// a deliberate escape hatch for replaying a captured payload in tests.
  ///
  /// Throws [StripeSignatureVerificationError] when the header cannot be
  /// parsed, when no `v1` signature matches the recomputed HMAC, when the
  /// timestamp falls outside [tolerance], or when the payload is not valid
  /// JSON once the signature has verified.
  static Event constructEvent({
    required Object payload,
    required String header,
    required String secret,
    int tolerance = 300,
  }) {
    final payloadBytes = _bytesOf(payload);
    final payloadForError = payload is String
        ? payload
        : utf8.decode(payloadBytes, allowMalformed: true);
    final parsed = _parseSignatureHeader(header);
    if (parsed == null) {
      throw StripeSignatureVerificationError(
        message: 'Unable to extract timestamp and signatures from header',
        header: header,
        payload: payloadForError,
      );
    }

    final expectedSignature = stripeHmacSha256HexBytes(
      [...utf8.encode('${parsed.timestamp}.'), ...payloadBytes],
      secret,
    );
    final matched = parsed.v1Signatures
        .any((signature) => stripeSecureCompare(signature, expectedSignature));
    if (!matched) {
      throw StripeSignatureVerificationError(
        message:
            'No signatures found matching the expected signature for payload',
        header: header,
        payload: payloadForError,
      );
    }

    if (tolerance > 0) {
      final nowSeconds = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      if (nowSeconds - parsed.timestamp > tolerance) {
        throw StripeSignatureVerificationError(
          message: 'Timestamp outside the tolerance zone',
          header: header,
          payload: payloadForError,
        );
      }
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(payloadBytes));
    } on FormatException {
      throw StripeSignatureVerificationError(
        message: 'Unable to parse payload as JSON',
        header: header,
        payload: payloadForError,
      );
    }
    if (decoded is! Map<String, Object?>) {
      throw StripeSignatureVerificationError(
        message: 'Unable to parse payload as JSON',
        header: header,
        payload: payloadForError,
      );
    }
    return Event.fromJson(decoded);
  }
}

List<int> _bytesOf(Object payload) => switch (payload) {
      final String string => utf8.encode(string),
      final List<int> bytes => bytes,
      _ => throw ArgumentError.value(
          payload,
          'payload',
          'must be a String or a List<int>',
        ),
    };

typedef _ParsedSignatureHeader = ({int timestamp, List<String> v1Signatures});

_ParsedSignatureHeader? _parseSignatureHeader(String header) {
  int? timestamp;
  final v1Signatures = <String>[];
  for (final part in header.split(',')) {
    final separatorIndex = part.indexOf('=');
    if (separatorIndex == -1) {
      continue;
    }
    final key = part.substring(0, separatorIndex).trim();
    final value = part.substring(separatorIndex + 1).trim();
    if (key == 't') {
      timestamp = int.tryParse(value);
    } else if (key == 'v1') {
      v1Signatures.add(value);
    }
  }
  if (timestamp == null || v1Signatures.isEmpty) {
    return null;
  }
  return (timestamp: timestamp, v1Signatures: v1Signatures);
}
