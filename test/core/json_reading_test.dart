import 'package:stripe_client/src/core/exceptions.dart';
import 'package:stripe_client/src/core/json_reading.dart';
import 'package:test/test.dart';

void main() {
  group('optString', () {
    test('returns null for a missing key', () {
      expect(<String, Object?>{}.optString('name'), isNull);
    });

    test('returns null for a key present with a null value', () {
      expect(<String, Object?>{'name': null}.optString('name'), isNull);
    });

    test('returns null for a key of an unexpected type', () {
      expect(<String, Object?>{'name': 42}.optString('name'), isNull);
    });

    test('returns the value for a well-formed string', () {
      expect(<String, Object?>{'name': 'invoice'}.optString('name'), 'invoice');
    });
  });

  group('optInt', () {
    test('returns null for a missing key', () {
      expect(<String, Object?>{}.optInt('amount'), isNull);
    });

    test('returns null for a key present with a null value', () {
      expect(<String, Object?>{'amount': null}.optInt('amount'), isNull);
    });

    test('returns null for a key of an unexpected type', () {
      expect(
          <String, Object?>{'amount': 'not a number'}.optInt('amount'), isNull);
    });

    test('returns the value for a well-formed int', () {
      expect(<String, Object?>{'amount': 1099}.optInt('amount'), 1099);
    });

    test('accepts a whole-valued double, since JSON has one numeric type', () {
      expect(<String, Object?>{'amount': 1099.0}.optInt('amount'), 1099);
    });

    test('returns null for a double with a genuine fractional part', () {
      expect(<String, Object?>{'amount': 10.5}.optInt('amount'), isNull);
    });

    test('returns null for non-finite doubles', () {
      expect(<String, Object?>{'amount': double.nan}.optInt('amount'), isNull);
      expect(<String, Object?>{'amount': double.infinity}.optInt('amount'),
          isNull);
      expect(
          <String, Object?>{'amount': double.negativeInfinity}.optInt('amount'),
          isNull);
    });
  });

  group('optDouble', () {
    test('returns null for a missing key', () {
      expect(<String, Object?>{}.optDouble('percent'), isNull);
    });

    test('returns null for a key present with a null value', () {
      expect(<String, Object?>{'percent': null}.optDouble('percent'), isNull);
    });

    test('returns null for a key of an unexpected type', () {
      expect(<String, Object?>{'percent': 'not a number'}.optDouble('percent'),
          isNull);
    });

    test('returns the value for a well-formed double', () {
      expect(<String, Object?>{'percent': 12.5}.optDouble('percent'), 12.5);
    });

    test('widens an int, since JSON has one numeric type', () {
      expect(<String, Object?>{'percent': 12}.optDouble('percent'), 12.0);
    });
  });

  group('optBool', () {
    test('returns null for a missing key', () {
      expect(<String, Object?>{}.optBool('livemode'), isNull);
    });

    test('returns null for a key present with a null value', () {
      expect(<String, Object?>{'livemode': null}.optBool('livemode'), isNull);
    });

    test('returns null for a key of an unexpected type', () {
      expect(<String, Object?>{'livemode': 'true'}.optBool('livemode'), isNull);
    });

    test('returns the value for a well-formed bool', () {
      expect(<String, Object?>{'livemode': true}.optBool('livemode'), isTrue);
      expect(<String, Object?>{'livemode': false}.optBool('livemode'), isFalse);
    });
  });

  group('optUnixTime', () {
    test('returns null for a missing key', () {
      expect(<String, Object?>{}.optUnixTime('created'), isNull);
    });

    test('returns null for a key present with a null value', () {
      expect(<String, Object?>{'created': null}.optUnixTime('created'), isNull);
    });

    test('returns null for a key of an unexpected type', () {
      expect(<String, Object?>{'created': 'yesterday'}.optUnixTime('created'),
          isNull);
    });

    test('converts seconds since the epoch to a UTC DateTime', () {
      final result = <String, Object?>{'created': 0}.optUnixTime('created');
      expect(result, DateTime.utc(1970));
      expect(result!.isUtc, isTrue);
    });

    test('never returns local time', () {
      final result =
          <String, Object?>{'created': 1700000000}.optUnixTime('created');
      expect(result!.isUtc, isTrue);
      expect(
        result,
        DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000, isUtc: true),
      );
    });

    test('inherits the whole-valued-double tolerance from optInt', () {
      expect(<String, Object?>{'created': 0.0}.optUnixTime('created'),
          DateTime.utc(1970));
    });
  });

  group('optStringMap', () {
    test('returns an empty map for a missing key', () {
      expect(<String, Object?>{}.optStringMap('metadata'), isEmpty);
    });

    test('returns an empty map for a key present with a null value', () {
      expect(<String, Object?>{'metadata': null}.optStringMap('metadata'),
          isEmpty);
    });

    test('returns an empty map for a key of an unexpected type', () {
      expect(
          <String, Object?>{'metadata': 'not a map'}.optStringMap('metadata'),
          isEmpty);
    });

    test('returns a well-formed string-to-string map unchanged', () {
      expect(
        <String, Object?>{
          'metadata': {'order_id': '42'},
        }.optStringMap('metadata'),
        {'order_id': '42'},
      );
    });

    test('stringifies a non-string value rather than dropping the key', () {
      expect(
        <String, Object?>{
          'metadata': {'count': 3, 'active': true},
        }.optStringMap('metadata'),
        {'count': '3', 'active': 'true'},
      );
    });

    test('drops an entry whose value is null', () {
      expect(
        <String, Object?>{
          'metadata': {'order_id': '42', 'gone': null},
        }.optStringMap('metadata'),
        {'order_id': '42'},
      );
    });
  });

  group('optList', () {
    test('returns an empty list for a missing key', () {
      expect(<String, Object?>{}.optList<Object?>('items', (e) => e), isEmpty);
    });

    test('returns an empty list for a key present with a null value', () {
      expect(
          <String, Object?>{'items': null}.optList<Object?>('items', (e) => e),
          isEmpty);
    });

    test('returns an empty list for a key of an unexpected type', () {
      expect(
        <String, Object?>{'items': 'not a list'}
            .optList<Object?>('items', (e) => e),
        isEmpty,
      );
    });

    test('applies fromElement to every element of a well-formed list', () {
      final result = <String, Object?>{
        'items': [1, 2, 3],
      }.optList<int>('items', (e) => (e as int) * 10);
      expect(result, [10, 20, 30]);
    });
  });

  group('optObject', () {
    test('returns null for a missing key', () {
      expect(<String, Object?>{}.optObject('address'), isNull);
    });

    test('returns null for a key present with a null value', () {
      expect(<String, Object?>{'address': null}.optObject('address'), isNull);
    });

    test('returns null for a key of an unexpected type', () {
      expect(<String, Object?>{'address': 'not an object'}.optObject('address'),
          isNull);
    });

    test('returns a well-formed nested object unchanged', () {
      expect(
        <String, Object?>{
          'address': {'city': 'Paris'},
        }.optObject('address'),
        {'city': 'Paris'},
      );
    });
  });

  group('optNested', () {
    test('returns null without calling fromJson for a missing key', () {
      var called = false;
      final result = <String, Object?>{}.optNested('address', (m) {
        called = true;
        return m;
      });
      expect(result, isNull);
      expect(called, isFalse);
    });

    test(
        'returns null without calling fromJson for a key of an unexpected type',
        () {
      var called = false;
      final result =
          <String, Object?>{'address': 'nope'}.optNested('address', (m) {
        called = true;
        return m;
      });
      expect(result, isNull);
      expect(called, isFalse);
    });

    test('decodes a well-formed nested object with fromJson', () {
      final result = <String, Object?>{
        'address': {'city': 'Paris'},
      }.optNested('address', (m) => m.optString('city'));
      expect(result, 'Paris');
    });

    test('propagates an exception thrown by fromJson', () {
      expect(
        () => <String, Object?>{'address': <String, Object?>{}}.optNested(
          'address',
          (m) => m.requireString('city', 'Address'),
        ),
        throwsA(isA<StripeDecodeException>()),
      );
    });
  });

  group('requireString', () {
    test('throws, naming the object and key, for a missing key', () {
      expect(
        () => <String, Object?>{}.requireString('id', 'Invoice'),
        throwsA(
          isA<StripeDecodeException>().having(
            (e) => e.message,
            'message',
            allOf(contains('Invoice'), contains('id')),
          ),
        ),
      );
    });

    test('throws for a key present with a null value', () {
      expect(
        () => <String, Object?>{'id': null}.requireString('id', 'Invoice'),
        throwsA(isA<StripeDecodeException>()),
      );
    });

    test('throws, naming the object and key, for a key of an unexpected type',
        () {
      expect(
        () => <String, Object?>{'id': 42}.requireString('id', 'Invoice'),
        throwsA(
          isA<StripeDecodeException>().having(
            (e) => e.message,
            'message',
            allOf(contains('Invoice'), contains('id')),
          ),
        ),
      );
    });

    test('returns the value for a well-formed string', () {
      expect(<String, Object?>{'id': 'in_123'}.requireString('id', 'Invoice'),
          'in_123');
    });
  });
}
