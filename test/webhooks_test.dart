import 'dart:convert';

import 'package:stripe_client/src/crypto_util.dart';
import 'package:stripe_client/src/errors.dart';
import 'package:stripe_client/src/webhooks.dart';
import 'package:test/test.dart';

const String _secret = 'whsec_test_secret';

String _payloadJson({String type = 'invoice.paid'}) => jsonEncode({
      'id': 'evt_123',
      'object': 'event',
      'type': type,
      'created': 1731600000,
      'data': {
        'object': {'id': 'in_123', 'object': 'invoice'},
      },
    });

String _signatureFor(int timestamp, List<int> payloadBytes, String secret) =>
    stripeHmacSha256HexBytes(
      [...utf8.encode('$timestamp.'), ...payloadBytes],
      secret,
    );

String _headerFor(
  String payload, {
  int? timestamp,
  String secret = _secret,
}) {
  final resolvedTimestamp =
      timestamp ?? DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
  final signature =
      _signatureFor(resolvedTimestamp, utf8.encode(payload), secret);
  return 't=$resolvedTimestamp,v1=$signature';
}

void main() {
  group('StripeWebhooks.constructEvent', () {
    test('verifies a valid signature and decodes the event', () {
      final payload = _payloadJson();
      final header = _headerFor(payload);

      final event = StripeWebhooks.constructEvent(
        payload: payload,
        header: header,
        secret: _secret,
      );

      expect(event.id, 'evt_123');
      expect(event.type, 'invoice.paid');
      expect(event.data!.object['id'], 'in_123');
    });

    test('accepts the payload as raw bytes, not just a String', () {
      final payload = _payloadJson();
      final payloadBytes = utf8.encode(payload);
      final header = _headerFor(payload);

      final event = StripeWebhooks.constructEvent(
        payload: payloadBytes,
        header: header,
        secret: _secret,
      );

      expect(event.id, 'evt_123');
    });

    test('throws when the payload was tampered with after signing', () {
      final payload = _payloadJson();
      final header = _headerFor(payload);
      final tamperedPayload = _payloadJson(type: 'invoice.voided');

      expect(
        () => StripeWebhooks.constructEvent(
          payload: tamperedPayload,
          header: header,
          secret: _secret,
        ),
        throwsA(isA<StripeSignatureVerificationError>()),
      );
    });

    test('throws when the timestamp is outside the tolerance window', () {
      final payload = _payloadJson();
      final oldTimestamp =
          DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000 - 3600;
      final header = _headerFor(payload, timestamp: oldTimestamp);

      expect(
        () => StripeWebhooks.constructEvent(
          payload: payload,
          header: header,
          secret: _secret,
          tolerance: 300,
        ),
        throwsA(
          isA<StripeSignatureVerificationError>().having(
            (e) => e.message,
            'message',
            contains('Timestamp'),
          ),
        ),
      );
    });

    test('tolerance: 0 disables the timestamp check entirely', () {
      final payload = _payloadJson();
      final oldTimestamp =
          DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000 - 36000;
      final header = _headerFor(payload, timestamp: oldTimestamp);

      final event = StripeWebhooks.constructEvent(
        payload: payload,
        header: header,
        secret: _secret,
        tolerance: 0,
      );

      expect(event.id, 'evt_123');
    });

    test('accepts the payload when only the second of two v1 entries matches',
        () {
      final payload = _payloadJson();
      final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final payloadBytes = utf8.encode(payload);
      final wrongSignature =
          _signatureFor(timestamp, payloadBytes, 'whsec_wrong');
      final correctSignature = _signatureFor(timestamp, payloadBytes, _secret);
      final header = 't=$timestamp,v1=$wrongSignature,v1=$correctSignature';

      final event = StripeWebhooks.constructEvent(
        payload: payload,
        header: header,
        secret: _secret,
      );

      expect(event.id, 'evt_123');
    });

    test('throws for a malformed header', () {
      final payload = _payloadJson();

      expect(
        () => StripeWebhooks.constructEvent(
          payload: payload,
          header: 'not-a-valid-header',
          secret: _secret,
        ),
        throwsA(
          isA<StripeSignatureVerificationError>().having(
            (e) => e.message,
            'message',
            contains('Unable to extract'),
          ),
        ),
      );
    });

    test('throws when no v0/v1 pair at all is present', () {
      final payload = _payloadJson();
      final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

      expect(
        () => StripeWebhooks.constructEvent(
          payload: payload,
          header: 't=$timestamp,v0=deadbeef',
          secret: _secret,
        ),
        throwsA(isA<StripeSignatureVerificationError>()),
      );
    });

    test('throws when the verified payload is not valid JSON', () {
      const payload = 'not json at all';
      final header = _headerFor(payload);

      expect(
        () => StripeWebhooks.constructEvent(
          payload: payload,
          header: header,
          secret: _secret,
        ),
        throwsA(
          isA<StripeSignatureVerificationError>().having(
            (e) => e.message,
            'message',
            contains('Unable to parse payload as JSON'),
          ),
        ),
      );
    });

    test(
        'throws when the verified payload decodes to something other than a map',
        () {
      const payload = '[1, 2, 3]';
      final header = _headerFor(payload);

      expect(
        () => StripeWebhooks.constructEvent(
          payload: payload,
          header: header,
          secret: _secret,
        ),
        throwsA(isA<StripeSignatureVerificationError>()),
      );
    });

    test('the thrown error carries the header and payload', () {
      final payload = _payloadJson();
      const header = 'garbage';

      try {
        StripeWebhooks.constructEvent(
            payload: payload, header: header, secret: _secret);
        fail('expected a StripeSignatureVerificationError');
      } on StripeSignatureVerificationError catch (error) {
        expect(error.header, header);
        expect(error.payload, payload);
      }
    });

    test('a mismatched signature over List<int> bytes still names the payload',
        () {
      final payloadBytes = utf8.encode(_payloadJson());
      const header = 't=1731600000,v1=deadbeef';

      try {
        StripeWebhooks.constructEvent(
            payload: payloadBytes, header: header, secret: _secret);
        fail('expected a StripeSignatureVerificationError');
      } on StripeSignatureVerificationError catch (error) {
        expect(error.payload, utf8.decode(payloadBytes));
      }
    });

    test('throws ArgumentError when payload is neither a String nor bytes', () {
      expect(
        () => StripeWebhooks.constructEvent(
          payload: 42,
          header: 't=1731600000,v1=deadbeef',
          secret: _secret,
        ),
        throwsArgumentError,
      );
    });
  });
}
