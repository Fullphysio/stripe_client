import 'package:stripe_client/src/resources/event.dart';
import 'package:test/test.dart';

void main() {
  group('EventData.fromJson', () {
    test('decodes the raw object', () {
      final data = EventData.fromJson({
        'object': {'id': 'in_123', 'object': 'invoice', 'status': 'paid'},
      });

      expect(
          data.object, {'id': 'in_123', 'object': 'invoice', 'status': 'paid'});
    });

    test('defaults object to an empty map when absent', () {
      final data = EventData.fromJson(<String, Object?>{});
      expect(data.object, isEmpty);
    });

    test('toString shows the object', () {
      const data = EventData(object: {'id': 'in_123'});
      expect(data.toString(), 'EventData(object: {id: in_123})');
    });
  });

  group('Event.fromJson', () {
    test('decodes a realistic invoice.paid event', () {
      final event = Event.fromJson({
        'id': 'evt_123',
        'object': 'event',
        'type': 'invoice.paid',
        'api_version': '2025-11-17.clover',
        'created': 1731600000,
        'livemode': false,
        'data': {
          'object': {'id': 'in_123', 'object': 'invoice', 'status': 'paid'},
        },
      });

      expect(event.id, 'evt_123');
      expect(event.type, 'invoice.paid');
      expect(event.apiVersion, '2025-11-17.clover');
      expect(event.created, isNotNull);
      expect(event.livemode, isFalse);
      expect(event.data!.object['status'], 'paid');
    });

    test('leaves data null when absent', () {
      final event = Event.fromJson({'id': 'evt_123', 'object': 'event'});
      expect(event.data, isNull);
      expect(event.type, isNull);
    });

    test('throws when id is missing', () {
      expect(
        () => Event.fromJson(<String, Object?>{}),
        throwsA(isA<Object>()),
      );
    });

    test('toString summarises id and type', () {
      const event = Event(id: 'evt_123', type: 'invoice.paid');
      expect(event.toString(), 'Event(id: evt_123, type: invoice.paid)');
    });
  });
}
