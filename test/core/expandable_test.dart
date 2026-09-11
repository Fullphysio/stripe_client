import 'package:stripe_client/src/core/exceptions.dart';
import 'package:stripe_client/src/core/expandable.dart';
import 'package:stripe_client/src/core/json_reading.dart';
import 'package:test/test.dart';

class _Invoice {
  const _Invoice(this.id, this.total);

  final String id;
  final int total;

  static _Invoice fromJson(Map<String, Object?> json) =>
      _Invoice(json.requireString('id', 'Invoice'), json.optInt('total') ?? 0);

  @override
  bool operator ==(Object other) =>
      other is _Invoice && other.id == id && other.total == total;

  @override
  int get hashCode => Object.hash(id, total);
}

void main() {
  group('Expandable.id', () {
    test('carries the id with no value', () {
      const expandable = Expandable<_Invoice>.id('in_123');
      expect(expandable.id, 'in_123');
      expect(expandable.value, isNull);
      expect(expandable.isExpanded, isFalse);
    });
  });

  group('Expandable.expanded', () {
    test('carries both the id and the value', () {
      const invoice = _Invoice('in_123', 1000);
      const expandable = Expandable<_Invoice>.expanded('in_123', invoice);
      expect(expandable.id, 'in_123');
      expect(expandable.value, invoice);
      expect(expandable.isExpanded, isTrue);
    });
  });

  group('Expandable.fromJson', () {
    test('given a String, decodes to an unexpanded reference', () {
      final expandable = Expandable<_Invoice>.fromJson(
        'in_123',
        _Invoice.fromJson,
        (invoice) => invoice.id,
      );
      expect(expandable.isExpanded, isFalse);
      expect(expandable.id, 'in_123');
      expect(expandable.value, isNull);
    });

    test(
      'given an object, decodes to an expanded reference and reads the id back out',
      () {
        final expandable = Expandable<_Invoice>.fromJson(
          {'id': 'in_123', 'total': 1000},
          _Invoice.fromJson,
          (invoice) => invoice.id,
        );
        expect(expandable.isExpanded, isTrue);
        expect(expandable.id, 'in_123');
        expect(expandable.value, const _Invoice('in_123', 1000));
      },
    );

    test('given something invalid, throws StripeDecodeException', () {
      expect(
        () => Expandable<_Invoice>.fromJson(
            42, _Invoice.fromJson, (invoice) => invoice.id),
        throwsA(isA<StripeDecodeException>()),
      );
    });

    test('given null, throws StripeDecodeException rather than swallowing it',
        () {
      expect(
        () => Expandable<_Invoice>.fromJson(
            null, _Invoice.fromJson, (invoice) => invoice.id),
        throwsA(isA<StripeDecodeException>()),
      );
    });
  });

  group('toJson', () {
    test(
        'encodes an unexpanded reference as the bare id, without calling valueToJson',
        () {
      const expandable = Expandable<_Invoice>.id('in_123');
      var called = false;
      final json = expandable.toJson((invoice) {
        called = true;
        return invoice.id;
      });
      expect(json, 'in_123');
      expect(called, isFalse);
    });

    test('encodes an expanded reference with valueToJson', () {
      const expandable =
          Expandable<_Invoice>.expanded('in_123', _Invoice('in_123', 1000));
      final json = expandable.toJson(
        (invoice) => {'id': invoice.id, 'total': invoice.total},
      );
      expect(json, {'id': 'in_123', 'total': 1000});
    });
  });

  group('equality', () {
    test('two unexpanded references with the same id are equal', () {
      expect(const Expandable<_Invoice>.id('in_123'),
          const Expandable<_Invoice>.id('in_123'));
    });

    test('two expanded references with the same id and value are equal', () {
      expect(
        const Expandable<_Invoice>.expanded('in_123', _Invoice('in_123', 1000)),
        const Expandable<_Invoice>.expanded('in_123', _Invoice('in_123', 1000)),
      );
    });

    test(
        'an unexpanded and an expanded reference with the same id are not equal',
        () {
      expect(
        const Expandable<_Invoice>.id('in_123'),
        isNot(const Expandable<_Invoice>.expanded(
            'in_123', _Invoice('in_123', 1000))),
      );
    });

    test('hashCode agrees with equal instances', () {
      expect(
        const Expandable<_Invoice>.id('in_123').hashCode,
        const Expandable<_Invoice>.id('in_123').hashCode,
      );
    });
  });

  group('StripeStub', () {
    test('fromJson reads id, object, and keeps the whole map as raw', () {
      final json = {'id': 'acct_123', 'object': 'account', 'extra': true};
      final stub = StripeStub.fromJson(json);
      expect(stub.id, 'acct_123');
      expect(stub.object, 'account');
      expect(stub.raw, json);
    });

    test('fromJson never throws when id and object are absent', () {
      final stub = StripeStub.fromJson(<String, Object?>{});
      expect(stub.id, isNull);
      expect(stub.object, isNull);
    });

    test('equality compares id and object only, ignoring raw', () {
      final a =
          StripeStub.fromJson({'id': 'acct_123', 'object': 'account', 'v': 1});
      final b =
          StripeStub.fromJson({'id': 'acct_123', 'object': 'account', 'v': 2});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('stubs with different ids are not equal', () {
      final a = StripeStub.fromJson({'id': 'acct_123', 'object': 'account'});
      final b = StripeStub.fromJson({'id': 'acct_456', 'object': 'account'});
      expect(a, isNot(b));
    });

    test('idOf returns the id when the stub carries one', () {
      final stub = StripeStub.fromJson({'id': 'acct_123', 'object': 'account'});
      expect(StripeStub.idOf(stub), 'acct_123');
    });

    test('idOf throws when the expanded object carries no id', () {
      final stub = StripeStub.fromJson(<String, Object?>{'object': 'account'});
      expect(
        () => StripeStub.idOf(stub, fieldName: 'charge.on_behalf_of'),
        throwsA(
          isA<StripeDecodeException>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('charge.on_behalf_of'),
              contains('no "id"'),
            ),
          ),
        ),
      );
    });

    test('idOf wired through Expandable resolves a pruned reference', () {
      final expandable = Expandable<StripeStub>.fromJson(
        {'id': 'acct_123', 'object': 'account', 'country': 'FR'},
        StripeStub.fromJson,
        StripeStub.idOf,
        fieldName: 'charge.on_behalf_of',
      );
      expect(expandable.id, 'acct_123');
      expect(expandable.isExpanded, isTrue);
      expect(expandable.value?.raw['country'], 'FR');
    });
  });

  group('decode failures name the field', () {
    test('fromJson reports fieldName when the payload is neither id nor object',
        () {
      expect(
        () => Expandable<StripeStub>.fromJson(
          42,
          StripeStub.fromJson,
          StripeStub.idOf,
          fieldName: 'subscription.latest_invoice',
        ),
        throwsA(
          isA<StripeDecodeException>().having(
            (e) => e.message,
            'message',
            contains('subscription.latest_invoice'),
          ),
        ),
      );
    });

    test('fromJson omits the field clause when no fieldName is given', () {
      expect(
        () => Expandable<StripeStub>.fromJson(
          42,
          StripeStub.fromJson,
          StripeStub.idOf,
        ),
        throwsA(
          isA<StripeDecodeException>().having(
            (e) => e.message,
            'message',
            isNot(contains(' at ')),
          ),
        ),
      );
    });
  });
}
