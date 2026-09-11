import 'package:stripe_client/src/core/exceptions.dart';
import 'package:stripe_client/src/core/stripe_list.dart';
import 'package:test/test.dart';

void main() {
  group('StripeList.fromJson', () {
    test('decodes a well-formed list', () {
      final list = StripeList<String>.fromJson({
        'object': 'list',
        'data': [
          {'id': 'in_1'},
          {'id': 'in_2'},
        ],
        'has_more': true,
        'url': '/v1/invoices',
      }, (json) => json['id']! as String);

      expect(list.data, ['in_1', 'in_2']);
      expect(list.hasMore, isTrue);
      expect(list.url, '/v1/invoices');
    });

    test('treats an absent list as empty rather than throwing', () {
      final fromNull =
          StripeList<String>.fromJson(null, (json) => json['id']! as String);
      expect(fromNull.data, isEmpty);
      expect(fromNull.hasMore, isFalse);
      expect(fromNull.url, isNull);

      final fromNonMap =
          StripeList<String>.fromJson('nope', (json) => json['id']! as String);
      expect(fromNonMap.data, isEmpty);
      expect(fromNonMap.hasMore, isFalse);
    });

    test('defaults has_more to false when missing', () {
      final list = StripeList<String>.fromJson({
        'object': 'list',
        'data': <Object?>[],
      }, (json) => json['id']! as String);

      expect(list.hasMore, isFalse);
    });

    test('defaults data to an empty list when missing', () {
      final list = StripeList<String>.fromJson({
        'object': 'list',
        'has_more': false,
      }, (json) => json['id']! as String);

      expect(list.data, isEmpty);
    });

    test(
        'throws StripeDecodeException when a data element is not a JSON object',
        () {
      expect(
        () => StripeList<String>.fromJson({
          'object': 'list',
          'data': ['not an object'],
        }, (json) => json['id']! as String),
        throwsA(isA<StripeDecodeException>()),
      );
    });
  });

  group('StripeList construction', () {
    test('the default constructor defaults data to an empty list', () {
      const list = StripeList<String>(hasMore: false);
      expect(list.data, isEmpty);
      expect(list.url, isNull);
    });
  });
}
