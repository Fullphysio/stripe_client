import 'package:stripe_client/src/core/expand_params.dart';
import 'package:test/test.dart';

void main() {
  group('ExpandParams.toJson', () {
    test('encodes expand when given', () {
      const params = ExpandParams(expand: ['customer', 'discounts']);
      expect(params.toJson(), {
        'expand': ['customer', 'discounts'],
      });
    });

    test('omits expand from the map when not provided', () {
      const params = ExpandParams();
      expect(params.toJson(), isNot(contains('expand')));
      expect(params.toJson(), isEmpty);
    });
  });
}
