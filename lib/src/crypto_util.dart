import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Computes an HMAC-SHA256 signature over the UTF-8 encoding of [payload],
/// keyed with the UTF-8 encoding of [secret].
///
/// Returns the signature as lowercase hexadecimal, the format Stripe sends
/// in the `Stripe-Signature` webhook header and expects verification code
/// to reproduce.
///
/// If the payload is raw bytes that are not guaranteed to be valid UTF-8 —
/// for example a webhook request body read straight off the wire — decoding
/// it to a [String] first risks corrupting bytes that aren't valid UTF-8
/// before they ever reach the HMAC. Use [stripeHmacSha256HexBytes] instead
/// in that case.
String stripeHmacSha256Hex(String payload, String secret) {
  return stripeHmacSha256HexBytes(utf8.encode(payload), secret);
}

/// Computes an HMAC-SHA256 signature over the raw [payload] bytes, keyed
/// with the UTF-8 encoding of [secret].
///
/// Returns the signature as lowercase hexadecimal. Prefer this over
/// [stripeHmacSha256Hex] whenever [payload] is binary-safe data of
/// unverified encoding, such as a webhook request body, since it never
/// round-trips the bytes through [String] decoding.
String stripeHmacSha256HexBytes(List<int> payload, String secret) {
  final hmac = Hmac(sha256, utf8.encode(secret));
  return hmac.convert(payload).toString();
}

/// Compares [a] and [b] for equality in constant time, to avoid leaking
/// timing information that an attacker could use to forge a webhook
/// signature one byte at a time.
///
/// Unlike `==`, this never returns as soon as a difference is found: every
/// character pair is inspected via XOR-accumulation, so the amount of work
/// done depends only on the lengths of [a] and [b], never on where — or
/// whether — they first differ.
bool stripeSecureCompare(String a, String b) {
  if (a.length != b.length) {
    return false;
  }
  var result = 0;
  for (var i = 0; i < a.length; i++) {
    result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return result == 0;
}

final Random _uuidRandom = Random.secure();

/// Generates a random RFC 4122 version 4 UUID, formatted lowercase and
/// hyphenated as `xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx`, where the `4`
/// marks the version and `y` is one of `8`, `9`, `a`, or `b`.
///
/// Drawn from [Random.secure], a cryptographically secure random number
/// generator, so the result is unpredictable enough to use as an
/// idempotency key.
String stripeUuidV4() {
  final bytes = List<int>.generate(16, (_) => _uuidRandom.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  final hex =
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20, 32)}';
}
