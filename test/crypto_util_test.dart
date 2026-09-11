import 'dart:convert';

import 'package:stripe_client/src/crypto_util.dart';
import 'package:test/test.dart';

void main() {
  group('stripeHmacSha256Hex', () {
    test('matches the CryptoProvider known-answer vector for an empty payload',
        () {
      expect(
        stripeHmacSha256Hex('', 'test_secret'),
        'f7f9bd47fb987337b5796fdc1fdb9ba221d0d5396814bfcaf9521f43fd8927fd',
      );
    });

    test('matches the CryptoProvider known-answer vector for an emoji payload',
        () {
      expect(
        stripeHmacSha256Hex('\u{1F600}', 'test_secret'),
        '837da296d05c4fe31f61d5d7ead035099d9585a5bcde87de952012a78f0b0c43',
      );
    });

    test('returns lowercase hexadecimal, 64 characters long', () {
      final digest = stripeHmacSha256Hex('anything', 'secret');
      expect(digest, matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    test('agrees with stripeHmacSha256HexBytes for the same UTF-8 payload', () {
      const payload = 'a payload with unicode: café ☃';
      const secret = 'whsec_test';
      expect(
        stripeHmacSha256Hex(payload, secret),
        stripeHmacSha256HexBytes(utf8.encode(payload), secret),
      );
    });
  });

  group('stripeHmacSha256HexBytes', () {
    test('matches an external reference vector for non-UTF-8-safe bytes', () {
      final payload = [0xff, 0x00, 0x80, 0x41, 0xfe];
      expect(
        stripeHmacSha256HexBytes(payload, 'test_secret'),
        '9f29a6a8adcb41c0a68af7e1f7327389a615ce89468cd56450e0a02ace831a12',
      );
    });
  });

  group('stripeSecureCompare', () {
    test('is true for equal, non-empty strings', () {
      expect(stripeSecureCompare('same-value', 'same-value'), isTrue);
    });

    test('is true for two empty strings', () {
      expect(stripeSecureCompare('', ''), isTrue);
    });

    test('is false for equal-length strings differing in one character', () {
      expect(stripeSecureCompare('abcdef', 'abcxef'), isFalse);
    });

    test('is false for strings of different lengths', () {
      expect(stripeSecureCompare('short', 'a much longer string'), isFalse);
    });

    test('is false when only one side is empty', () {
      expect(stripeSecureCompare('', 'nonempty'), isFalse);
      expect(stripeSecureCompare('nonempty', ''), isFalse);
    });

    test(
      'behaves identically whether two equal-length strings differ at the '
      'first or the last byte, evidencing no early return on mismatch',
      () {
        const base = 'the quick brown fox jumps over the lazy dog!!!!';
        final differsAtStart = 'X${base.substring(1)}';
        final differsAtEnd = '${base.substring(0, base.length - 1)}X';

        expect(base.length, differsAtStart.length);
        expect(base.length, differsAtEnd.length);
        expect(stripeSecureCompare(base, differsAtStart), isFalse);
        expect(stripeSecureCompare(base, differsAtEnd), isFalse);
      },
    );
  });

  group('stripeUuidV4', () {
    final uuidPattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );

    test('matches the RFC 4122 v4 format, version and variant nibbles', () {
      for (var i = 0; i < 500; i++) {
        expect(stripeUuidV4(), matches(uuidPattern));
      }
    });

    test('is unique across many draws', () {
      final draws = List<String>.generate(2000, (_) => stripeUuidV4());
      expect(draws.toSet(), hasLength(draws.length));
    });
  });
}
