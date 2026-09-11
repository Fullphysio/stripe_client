import 'dart:io';

import 'package:test/test.dart';

import '../../tool/ir/resolve.dart';

void main() {
  group('resolveSchemas', () {
    test('follows a simple \$ref chain', () {
      final Map<String, Object?> spec = <String, Object?>{
        'components': <String, Object?>{
          'schemas': <String, Object?>{
            'a': <String, Object?>{
              'properties': <String, Object?>{
                'b': <String, Object?>{'\$ref': '#/components/schemas/b'},
              },
            },
            'b': <String, Object?>{
              'properties': <String, Object?>{
                'c': <String, Object?>{'\$ref': '#/components/schemas/c'},
              },
            },
            'c': <String, Object?>{'type': 'object'},
          },
        },
      };
      final ResolvedSchemas result = resolveSchemas(
        spec: spec,
        allowlist: _allowlist(resources: <String>['a']),
      );
      expect(result.schemas.keys, unorderedEquals(<String>['a', 'b', 'c']));
      expect(result.prunedReferences, isEmpty);
    });

    test('terminates on a cycle between two schemas', () {
      final Map<String, Object?> spec = <String, Object?>{
        'components': <String, Object?>{
          'schemas': <String, Object?>{
            'customer': <String, Object?>{
              'properties': <String, Object?>{
                'subscriptions': <String, Object?>{
                  '\$ref': '#/components/schemas/subscription',
                },
              },
            },
            'subscription': <String, Object?>{
              'properties': <String, Object?>{
                'customer': <String, Object?>{
                  '\$ref': '#/components/schemas/customer',
                },
              },
            },
          },
        },
      };
      final ResolvedSchemas result = resolveSchemas(
        spec: spec,
        allowlist: _allowlist(resources: <String>['customer']),
      );
      expect(
        result.schemas.keys,
        unorderedEquals(<String>['customer', 'subscription']),
      );
    });

    test('records a pruned ref instead of dropping it', () {
      final Map<String, Object?> spec = <String, Object?>{
        'components': <String, Object?>{
          'schemas': <String, Object?>{
            'charge': <String, Object?>{
              'properties': <String, Object?>{
                'on_behalf_of': <String, Object?>{
                  '\$ref': '#/components/schemas/account',
                },
              },
            },
            'account': <String, Object?>{'type': 'object'},
          },
        },
      };
      final ResolvedSchemas result = resolveSchemas(
        spec: spec,
        allowlist: _allowlist(
          resources: <String>['charge'],
          prune: <PruneRule>[
            const PruneRule(id: 'account', reason: 'Connect only.'),
          ],
        ),
      );
      expect(result.schemas.keys, unorderedEquals(<String>['charge']));
      expect(result.prunedReferences.keys, contains('account'));
      final PrunedReference pruned = result.prunedReferences['account']!;
      expect(pruned.reason, 'Connect only.');
      expect(pruned.referencedFrom, contains('charge.on_behalf_of'));
    });

    test('payment-method-type trim drops types outside the allowlist', () {
      final Map<String, Object?> spec = <String, Object?>{
        'components': <String, Object?>{
          'schemas': <String, Object?>{
            'payment_method': <String, Object?>{
              'properties': <String, Object?>{
                'type': <String, Object?>{
                  'enum': <String>['card', 'affirm'],
                },
                'card': <String, Object?>{
                  '\$ref': '#/components/schemas/payment_method_card',
                },
                'affirm': <String, Object?>{
                  '\$ref': '#/components/schemas/payment_method_affirm',
                },
              },
            },
            'payment_method_card': <String, Object?>{'type': 'object'},
            'payment_method_affirm': <String, Object?>{'type': 'object'},
          },
        },
      };
      final ResolvedSchemas result = resolveSchemas(
        spec: spec,
        allowlist: _allowlist(
          resources: <String>['payment_method'],
          paymentMethodTypes: <String>{'card'},
        ),
      );
      expect(
        result.schemas.keys,
        unorderedEquals(<String>['payment_method', 'payment_method_card']),
      );
      expect(result.prunedReferences.keys, contains('payment_method_affirm'));
      expect(
        result.prunedReferences['payment_method_affirm']!.referencedFrom,
        contains('payment_method.affirm'),
      );
    });

    test('an unresolvable seed fails loudly, naming the bad id', () {
      final Map<String, Object?> spec = <String, Object?>{
        'components': <String, Object?>{
          'schemas': <String, Object?>{
            'a': <String, Object?>{'type': 'object'},
          },
        },
      };
      expect(
        () => resolveSchemas(
          spec: spec,
          allowlist: _allowlist(resources: <String>['does_not_exist']),
        ),
        throwsA(
          isA<StateError>().having(
            (StateError e) => e.message,
            'message',
            contains('does_not_exist'),
          ),
        ),
      );
    });

    test('a \$ref to a schema missing from the spec fails loudly', () {
      final Map<String, Object?> spec = <String, Object?>{
        'components': <String, Object?>{
          'schemas': <String, Object?>{
            'a': <String, Object?>{
              'properties': <String, Object?>{
                'b': <String, Object?>{'\$ref': '#/components/schemas/b'},
              },
            },
          },
        },
      };
      expect(
        () => resolveSchemas(
          spec: spec,
          allowlist: _allowlist(resources: <String>['a']),
        ),
        throwsA(
          isA<StateError>().having(
            (StateError e) => e.message,
            'message',
            allOf(contains('a.b'), contains('"b"')),
          ),
        ),
      );
    });
  });

  group('Allowlist', () {
    test('parses the vendored allowlist.yaml', () {
      final Allowlist allowlist = Allowlist.load('tool/spec/allowlist.yaml');
      expect(allowlist.specTag, isNotEmpty);
      expect(allowlist.resources, isNotEmpty);
      expect(allowlist.paymentMethodTypes, isNotEmpty);
      expect(allowlist.prune, isNotEmpty);
    });

    test('fails loudly on a non-string resources entry', () {
      expect(
        () => Allowlist.parse('''
spec:
  tag: v1
  file: openapi/spec3.sdk.json
resources:
  - 1
paymentMethodTypes: []
'''),
        throwsFormatException,
      );
    });
  });

  group('loadVerifiedSpec', () {
    test('fails loudly when the digest does not match SPEC_SHA256', () {
      final Directory tempDir = Directory.systemTemp.createTempSync(
        'resolve_test_',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final File specFile = File('${tempDir.path}/spec.json')
        ..writeAsStringSync('{"components":{"schemas":{}}}');
      final File shaFile = File('${tempDir.path}/SPEC_SHA256')
        ..writeAsStringSync(
            '0000000000000000000000000000000000000000000000000000000000000000\n');

      expect(
        () => loadVerifiedSpec(
          specPath: specFile.path,
          shaPath: shaFile.path,
        ),
        throwsA(
          isA<StateError>().having(
            (StateError e) => e.message,
            'message',
            contains('does not match'),
          ),
        ),
      );
    });
  });

  group('real vendored spec', () {
    test('resolved schema count stays within budget', () {
      final Allowlist allowlist = Allowlist.load('tool/spec/allowlist.yaml');
      final Map<String, Object?> spec = loadVerifiedSpec(
        specPath: 'tool/spec/spec3.sdk.json',
        shaPath: 'tool/spec/SPEC_SHA256',
      );
      final ResolvedSchemas result = resolveSchemas(
        spec: spec,
        allowlist: allowlist,
      );
      expect(result.schemas.length, inInclusiveRange(300, 450));
    });
  });
}

Allowlist _allowlist({
  required List<String> resources,
  Set<String> paymentMethodTypes = const <String>{},
  List<PruneRule> prune = const <PruneRule>[],
}) {
  return Allowlist(
    specTag: 'test',
    specFile: 'test.json',
    resources: resources,
    paymentMethodTypes: paymentMethodTypes,
    prune: prune,
  );
}
