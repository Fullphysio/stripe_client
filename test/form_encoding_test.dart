import 'dart:convert';
import 'dart:io';

import 'package:stripe_client/src/form_encoding.dart';
import 'package:test/test.dart';

/// Every case here is compared against `test/fixtures/encoding_golden.json`,
/// captured from the real `stripe-node` (19.3.1) via its `httpClient`
/// injection seam — see `tool/capture_fixtures/encoding.js`.
void main() {
  final golden = jsonDecode(
    File('test/fixtures/encoding_golden.json').readAsStringSync(),
  ) as Map<String, Object?>;

  Map<String, String> decodeToMap(String encoded) {
    if (encoded.isEmpty) {
      return <String, String>{};
    }
    final result = <String, String>{};
    for (final pair in encoded.split('&')) {
      final splitIndex = pair.indexOf('=');
      final rawKey = splitIndex == -1 ? pair : pair.substring(0, splitIndex);
      final rawValue = splitIndex == -1 ? '' : pair.substring(splitIndex + 1);
      result[Uri.decodeComponent(rawKey)] = Uri.decodeComponent(rawValue);
    }
    return result;
  }

  void conforms(
    String name,
    Map<String, Object?> data, {
    bool alsoRaw = false,
  }) {
    test(name, () {
      final expected = golden[name]! as String;
      final actual = stripeFormEncode(data);
      expect(
        decodeToMap(actual),
        decodeToMap(expected),
        reason: 'diverges from stripe-node',
      );
      if (alsoRaw) {
        expect(actual, expected, reason: 'diverges from stripe-node (raw)');
      }
    });
  }

  conforms('flatScalars', {
    'name': 'Ada Lovelace',
    'description': 'First customer',
    'phone': '+14155552671',
  });

  conforms('nestedObject', {
    'address': {
      'line1': '1 Infinite Loop',
      'city': 'Cupertino',
      'country': 'US',
    },
  });

  conforms('deeplyNested', {
    'mode': 'payment',
    'success_url': 'https://example.com/success',
    'payment_intent_data': {
      'shipping': {
        'address': {
          'line1': '1 Infinite Loop',
          'city': 'Cupertino',
          'country': 'US',
        },
      },
    },
  });

  conforms('arrayOfScalars', {
    'mode': 'payment',
    'success_url': 'https://example.com/success',
    'payment_method_types': ['card', 'ideal', 'bancontact'],
  });

  conforms('arrayOfObjects', {
    'mode': 'payment',
    'success_url': 'https://example.com/success',
    'line_items': [
      {'price': 'price_123', 'quantity': 1},
      {'price': 'price_456', 'quantity': 2},
    ],
  });

  conforms('emptyArray', {
    'mode': 'payment',
    'success_url': 'https://example.com/success',
    'payment_method_types': <Object?>[],
  });

  conforms(
    'emptyObject',
    {'name': 'Empty Object Test', 'metadata': <String, Object?>{}},
    alsoRaw: true,
  );

  conforms(
    'nestedEmptyCascade',
    {
      'invoice_settings': {'custom_fields': <Object?>[]},
    },
    alsoRaw: true,
  );

  conforms('presentNull', {'description': null}, alsoRaw: true);

  conforms('booleanTrue', {
    'mode': 'payment',
    'success_url': 'https://example.com/success',
    'allow_promotion_codes': true,
  });

  conforms(
    'booleanFalse',
    {'cancel_at_period_end': false},
    alsoRaw: true,
  );

  conforms('wholeNumber', {'limit': 25.0}, alsoRaw: true);

  conforms('negativeNumber', {'balance': -1500}, alsoRaw: true);

  conforms(
    'dateNormal',
    {'created': DateTime.parse('2024-01-15T10:30:00.000Z')},
    alsoRaw: true,
  );

  conforms(
    'dateBeforeEpoch',
    {'created': DateTime.parse('1969-12-31T23:59:59.500Z')},
    alsoRaw: true,
  );

  conforms(
    'unicodeString',
    {'name': 'Zoë Åström 中文 😀'},
    alsoRaw: true,
  );

  conforms(
    'specialCharsString',
    {'description': "a!b*c'd(e)f~g h&i=j[k]l"},
    alsoRaw: true,
  );

  conforms('expandDottedPaths', {
    'expand': [
      'data.default_payment_method',
      'data.latest_invoice.payment_intent',
    ],
  });

  group('number formatting Dart cannot distinguish via the JS reference', () {
    test('whole double encodes without a decimal point', () {
      expect(stripeFormEncode({'n': 25.0}), 'n=25');
    });

    test('negative whole double encodes without a decimal point', () {
      expect(stripeFormEncode({'n': -7.0}), 'n=-7');
    });

    test('negative zero encodes as 0, matching String(-0) in JS', () {
      expect(stripeFormEncode({'n': -0.0}), 'n=0');
    });

    test('non-whole double keeps its normal Dart representation', () {
      expect(stripeFormEncode({'n': 19.99}), 'n=19.99');
    });
  });

  group('fail loud', () {
    test('throws on an unsupported value type', () {
      expect(
        () => stripeFormEncode({'n': Object()}),
        throwsArgumentError,
      );
    });

    test('throws on a non-String nested map key', () {
      expect(
        () => stripeFormEncode({
          'n': <int, Object?>{1: 'x'},
        }),
        throwsArgumentError,
      );
    });

    test('throws on a non-finite double', () {
      expect(
        () => stripeFormEncode({'n': double.nan}),
        throwsArgumentError,
      );
      expect(
        () => stripeFormEncode({'n': double.infinity}),
        throwsArgumentError,
      );
    });
  });
}
