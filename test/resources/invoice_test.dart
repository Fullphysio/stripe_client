import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stripe_client/src/core/expand_params.dart';
import 'package:stripe_client/src/resources/invoice.dart';
import 'package:stripe_client/src/transport/stripe_client.dart';
import 'package:test/test.dart';

void main() {
  group('InvoiceLineItem.fromJson', () {
    test('decodes a realistic payload', () {
      final lineItem = InvoiceLineItem.fromJson({
        'id': 'il_123',
        'object': 'line_item',
        'amount': 999,
        'currency': 'usd',
        'quantity': 1,
        'description': 'Premium plan',
      });

      expect(lineItem.id, 'il_123');
      expect(lineItem.amount, 999);
      expect(lineItem.currency, 'usd');
      expect(lineItem.quantity, 1);
      expect(lineItem.description, 'Premium plan');
    });

    test('throws when id is missing', () {
      expect(
        () => InvoiceLineItem.fromJson(<String, Object?>{}),
        throwsA(isA<Object>()),
      );
    });

    test('toString summarises id, amount and description', () {
      const lineItem =
          InvoiceLineItem(id: 'il_123', amount: 999, description: 'Plan');
      expect(
        lineItem.toString(),
        'InvoiceLineItem(id: il_123, amount: 999, description: Plan)',
      );
    });
  });

  group('InvoiceTaxAmount.fromJson', () {
    test('decodes amount and inclusive', () {
      final taxAmount =
          InvoiceTaxAmount.fromJson({'amount': 80, 'inclusive': false});
      expect(taxAmount.amount, 80);
      expect(taxAmount.inclusive, isFalse);
    });

    test('toString summarises amount and inclusive', () {
      const taxAmount = InvoiceTaxAmount(amount: 80, inclusive: false);
      expect(
        taxAmount.toString(),
        'InvoiceTaxAmount(amount: 80, inclusive: false)',
      );
    });
  });

  group('InvoiceDiscountAmount.fromJson', () {
    test('decodes a bare discount id when unexpanded', () {
      final discountAmount =
          InvoiceDiscountAmount.fromJson({'amount': 500, 'discount': 'di_123'});
      expect(discountAmount.amount, 500);
      expect(discountAmount.discount!.isExpanded, isFalse);
      expect(discountAmount.discount!.id, 'di_123');
    });

    test('decodes an expanded discount', () {
      final discountAmount = InvoiceDiscountAmount.fromJson({
        'amount': 500,
        'discount': {'id': 'di_123', 'object': 'discount'},
      });
      expect(discountAmount.discount!.isExpanded, isTrue);
    });

    test('leaves discount null when absent', () {
      final discountAmount = InvoiceDiscountAmount.fromJson({'amount': 500});
      expect(discountAmount.discount, isNull);
    });

    test('toString summarises amount', () {
      const discountAmount = InvoiceDiscountAmount(amount: 500);
      expect(discountAmount.toString(), 'InvoiceDiscountAmount(amount: 500)');
    });
  });

  group('Invoice.fromJson', () {
    test('decodes bare discount ids when the invoice has discounts', () {
      final invoice = Invoice.fromJson({
        'id': 'in_123',
        'object': 'invoice',
        'hosted_invoice_url': 'https://invoice.stripe.com/i/in_123',
        'status': 'paid',
        'amount_paid': 1999,
        'subtotal': 1999,
        'total': 1999,
        'currency': 'usd',
        'discounts': ['di_123', 'di_456'],
        'lines': {
          'object': 'list',
          'has_more': false,
          'url': '/v1/invoices/in_123/lines',
          'data': [
            {'id': 'il_123', 'object': 'line_item', 'amount': 1999},
          ],
        },
        'total_tax_amounts': [
          {'amount': 80, 'inclusive': false},
        ],
        'total_discount_amounts': [
          {'amount': 200, 'discount': 'di_123'},
        ],
      });

      expect(invoice.id, 'in_123');
      expect(invoice.hostedInvoiceUrl, 'https://invoice.stripe.com/i/in_123');
      expect(invoice.status, 'paid');
      expect(invoice.amountPaid, 1999);
      expect(invoice.subtotal, 1999);
      expect(invoice.total, 1999);
      expect(invoice.currency, 'usd');
      expect(invoice.discounts, hasLength(2));
      expect(invoice.discounts.first.isExpanded, isFalse);
      expect(invoice.discounts.first.id, 'di_123');
      expect(invoice.lines!.data, hasLength(1));
      expect(invoice.lines!.data.first.id, 'il_123');
      expect(invoice.totalTaxAmounts, hasLength(1));
      expect(invoice.totalTaxAmounts.first.amount, 80);
      expect(invoice.totalDiscountAmounts, hasLength(1));
      expect(invoice.totalDiscountAmounts.first.discount!.id, 'di_123');
    });

    test('decodes expanded discounts, reading promotion_code off each one', () {
      final invoice = Invoice.fromJson({
        'id': 'in_123',
        'object': 'invoice',
        'discounts': [
          {
            'id': 'di_123',
            'object': 'discount',
            'promotion_code': {
              'id': 'promo_123',
              'object': 'promotion_code',
              'code': 'SAVE10',
            },
          },
        ],
      });

      expect(invoice.discounts.first.isExpanded, isTrue);
      expect(
        invoice.discounts.first.value!.promotionCode!.value!.code,
        'SAVE10',
      );
    });

    test(
        'defaults discounts, totalTaxAmounts and totalDiscountAmounts to empty',
        () {
      final invoice = Invoice.fromJson({'id': 'in_123', 'object': 'invoice'});

      expect(invoice.discounts, isEmpty);
      expect(invoice.lines, isNull);
      expect(invoice.totalTaxAmounts, isEmpty);
      expect(invoice.totalDiscountAmounts, isEmpty);
    });

    test('throws when id is missing', () {
      expect(
        () => Invoice.fromJson(<String, Object?>{}),
        throwsA(isA<Object>()),
      );
    });

    test('toString summarises id, status, total and currency', () {
      const invoice =
          Invoice(id: 'in_123', status: 'paid', total: 1999, currency: 'usd');
      expect(
        invoice.toString(),
        'Invoice(id: in_123, status: paid, total: 1999, currency: usd)',
      );
    });
  });

  group('StripeClient.invoices.retrieve', () {
    test('sends a GET to /v1/invoices/{id} with expand=discounts', () async {
      http.Request? captured;
      final client = StripeClient(
        apiKey: 'sk_test_123',
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({'id': 'in_123', 'object': 'invoice'}),
            200,
          );
        }),
      );

      final invoice = await client.invoices
          .retrieve('in_123', const ExpandParams(expand: ['discounts']));

      expect(invoice.id, 'in_123');
      expect(captured!.method, 'GET');
      expect(captured!.url.path, '/v1/invoices/in_123');
      expect(captured!.url.query, 'expand%5B0%5D=discounts');
    });
  });
}
