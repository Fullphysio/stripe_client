import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stripe_client/src/resources/checkout_session.dart';
import 'package:stripe_client/src/transport/stripe_client.dart';
import 'package:test/test.dart';

void main() {
  group('CheckoutSessionMode', () {
    test('wireValue matches the enum name for every mode', () {
      expect(CheckoutSessionMode.payment.wireValue, 'payment');
      expect(CheckoutSessionMode.setup.wireValue, 'setup');
      expect(CheckoutSessionMode.subscription.wireValue, 'subscription');
    });
  });

  group('CheckoutSessionLineItemParams.toJson', () {
    test('encodes price and quantity', () {
      const params =
          CheckoutSessionLineItemParams(price: 'price_123', quantity: 2);
      expect(params.toJson(), {'price': 'price_123', 'quantity': 2});
    });

    test('toString summarises price and quantity', () {
      const params =
          CheckoutSessionLineItemParams(price: 'price_123', quantity: 2);
      expect(
        params.toString(),
        'CheckoutSessionLineItemParams(price: price_123, quantity: 2)',
      );
    });
  });

  group('CheckoutSessionDiscountParams.toJson', () {
    test('encodes promotionCode when given', () {
      const params = CheckoutSessionDiscountParams(promotionCode: 'promo_123');
      expect(params.toJson(), {'promotion_code': 'promo_123'});
    });

    test('encodes coupon when given', () {
      const params = CheckoutSessionDiscountParams(coupon: 'coupon_123');
      expect(params.toJson(), {'coupon': 'coupon_123'});
    });

    test('omits both when neither is given', () {
      const params = CheckoutSessionDiscountParams();
      expect(params.toJson(), isEmpty);
    });

    test('toString summarises promotionCode and coupon', () {
      const params = CheckoutSessionDiscountParams(promotionCode: 'promo_123');
      expect(
        params.toString(),
        'CheckoutSessionDiscountParams(promotionCode: promo_123, coupon: null)',
      );
    });
  });

  group('CheckoutSessionSubscriptionDataParams.toJson', () {
    test('encodes metadata and trialPeriodDays when given', () {
      const params = CheckoutSessionSubscriptionDataParams(
        metadata: {'plan': 'gold'},
        trialPeriodDays: 14,
      );
      expect(params.toJson(), {
        'metadata': {'plan': 'gold'},
        'trial_period_days': 14,
      });
    });

    test('omits fields when not given', () {
      const params = CheckoutSessionSubscriptionDataParams();
      expect(params.toJson(), isEmpty);
    });

    test('toString summarises trialPeriodDays', () {
      const params = CheckoutSessionSubscriptionDataParams(trialPeriodDays: 14);
      expect(
        params.toString(),
        'CheckoutSessionSubscriptionDataParams(trialPeriodDays: 14)',
      );
    });
  });

  group('CheckoutSessionPhoneNumberCollectionParams.toJson', () {
    test('encodes enabled', () {
      const params = CheckoutSessionPhoneNumberCollectionParams(enabled: true);
      expect(params.toJson(), {'enabled': true});
    });

    test('toString summarises enabled', () {
      const params = CheckoutSessionPhoneNumberCollectionParams(enabled: true);
      expect(
        params.toString(),
        'CheckoutSessionPhoneNumberCollectionParams(enabled: true)',
      );
    });
  });

  group('CheckoutSessionTaxIdCollectionParams.toJson', () {
    test('encodes enabled', () {
      const params = CheckoutSessionTaxIdCollectionParams(enabled: true);
      expect(params.toJson(), {'enabled': true});
    });

    test('toString summarises enabled', () {
      const params = CheckoutSessionTaxIdCollectionParams(enabled: true);
      expect(
        params.toString(),
        'CheckoutSessionTaxIdCollectionParams(enabled: true)',
      );
    });
  });

  group('CheckoutSessionAutomaticTaxParams.toJson', () {
    test('encodes enabled', () {
      const params = CheckoutSessionAutomaticTaxParams(enabled: true);
      expect(params.toJson(), {'enabled': true});
    });

    test('toString summarises enabled', () {
      const params = CheckoutSessionAutomaticTaxParams(enabled: true);
      expect(
        params.toString(),
        'CheckoutSessionAutomaticTaxParams(enabled: true)',
      );
    });
  });

  group('CheckoutSessionCustomerUpdateParams.toJson', () {
    test('encodes every field when given', () {
      const params = CheckoutSessionCustomerUpdateParams(
        address: 'auto',
        name: 'auto',
        shipping: 'auto',
      );
      expect(params.toJson(), {
        'address': 'auto',
        'name': 'auto',
        'shipping': 'auto',
      });
    });

    test('omits fields when not given', () {
      const params = CheckoutSessionCustomerUpdateParams();
      expect(params.toJson(), isEmpty);
    });

    test('toString summarises address, name and shipping', () {
      const params = CheckoutSessionCustomerUpdateParams(address: 'auto');
      expect(
        params.toString(),
        'CheckoutSessionCustomerUpdateParams('
        'address: auto, name: null, shipping: null)',
      );
    });
  });

  group('CheckoutSessionCreateParams.toJson', () {
    test('encodes required fields and the line_items array', () {
      const params = CheckoutSessionCreateParams(
        mode: CheckoutSessionMode.payment,
        lineItems: [
          CheckoutSessionLineItemParams(price: 'price_123', quantity: 2)
        ],
        successUrl: 'https://example.com/success',
        cancelUrl: 'https://example.com/cancel',
      );

      expect(params.toJson(), {
        'mode': 'payment',
        'line_items': [
          {'price': 'price_123', 'quantity': 2},
        ],
        'success_url': 'https://example.com/success',
        'cancel_url': 'https://example.com/cancel',
      });
    });

    test('encodes every optional field, including the discounts array', () {
      const params = CheckoutSessionCreateParams(
        mode: CheckoutSessionMode.subscription,
        lineItems: [
          CheckoutSessionLineItemParams(price: 'price_123', quantity: 1)
        ],
        successUrl: 'https://example.com/success',
        cancelUrl: 'https://example.com/cancel',
        customer: 'cus_123',
        customerEmail: 'a@b.com',
        discounts: [CheckoutSessionDiscountParams(promotionCode: 'promo_123')],
        subscriptionData:
            CheckoutSessionSubscriptionDataParams(trialPeriodDays: 7),
        metadata: {'source': 'campaign'},
        clientReferenceId: 'order_1',
        locale: 'fr',
        allowPromotionCodes: true,
        phoneNumberCollection:
            CheckoutSessionPhoneNumberCollectionParams(enabled: true),
        taxIdCollection: CheckoutSessionTaxIdCollectionParams(enabled: true),
        automaticTax: CheckoutSessionAutomaticTaxParams(enabled: true),
        customerUpdate: CheckoutSessionCustomerUpdateParams(
          address: 'auto',
          name: 'auto',
          shipping: 'auto',
        ),
        billingAddressCollection: 'required',
      );

      expect(params.toJson(), {
        'mode': 'subscription',
        'line_items': [
          {'price': 'price_123', 'quantity': 1},
        ],
        'success_url': 'https://example.com/success',
        'cancel_url': 'https://example.com/cancel',
        'customer': 'cus_123',
        'customer_email': 'a@b.com',
        'discounts': [
          {'promotion_code': 'promo_123'},
        ],
        'subscription_data': {'trial_period_days': 7},
        'metadata': {'source': 'campaign'},
        'client_reference_id': 'order_1',
        'locale': 'fr',
        'allow_promotion_codes': true,
        'phone_number_collection': {'enabled': true},
        'tax_id_collection': {'enabled': true},
        'automatic_tax': {'enabled': true},
        'customer_update': {
          'address': 'auto',
          'name': 'auto',
          'shipping': 'auto',
        },
        'billing_address_collection': 'required',
      });
    });

    test(
        'omits phoneNumberCollection, taxIdCollection, automaticTax, '
        'customerUpdate and billingAddressCollection when not given', () {
      const params = CheckoutSessionCreateParams(
        mode: CheckoutSessionMode.payment,
        lineItems: [
          CheckoutSessionLineItemParams(price: 'price_123', quantity: 1)
        ],
        successUrl: 'https://example.com/success',
        cancelUrl: 'https://example.com/cancel',
      );

      final json = params.toJson();
      expect(json.containsKey('phone_number_collection'), isFalse);
      expect(json.containsKey('tax_id_collection'), isFalse);
      expect(json.containsKey('automatic_tax'), isFalse);
      expect(json.containsKey('customer_update'), isFalse);
      expect(json.containsKey('billing_address_collection'), isFalse);
    });

    test('toString summarises mode and lineItems length', () {
      const params = CheckoutSessionCreateParams(
        mode: CheckoutSessionMode.payment,
        lineItems: [
          CheckoutSessionLineItemParams(price: 'price_123', quantity: 1)
        ],
        successUrl: 'https://example.com/success',
        cancelUrl: 'https://example.com/cancel',
      );
      expect(
        params.toString(),
        'CheckoutSessionCreateParams(mode: CheckoutSessionMode.payment, '
        'lineItems: 1)',
      );
    });
  });

  group('CheckoutSession.fromJson', () {
    test('decodes a bare customer and subscription id when unexpanded', () {
      final session = CheckoutSession.fromJson({
        'id': 'cs_123',
        'object': 'checkout.session',
        'url': 'https://checkout.stripe.com/pay/cs_123',
        'customer': 'cus_123',
        'subscription': 'sub_123',
        'client_reference_id': 'order_1',
        'mode': 'subscription',
        'status': 'open',
      });

      expect(session.id, 'cs_123');
      expect(session.url, 'https://checkout.stripe.com/pay/cs_123');
      expect(session.customer!.isExpanded, isFalse);
      expect(session.customer!.id, 'cus_123');
      expect(session.subscription!.isExpanded, isFalse);
      expect(session.subscription!.id, 'sub_123');
      expect(session.clientReferenceId, 'order_1');
      expect(session.mode, 'subscription');
      expect(session.status, 'open');
    });

    test('decodes an expanded customer and subscription', () {
      final session = CheckoutSession.fromJson({
        'id': 'cs_123',
        'object': 'checkout.session',
        'customer': {'id': 'cus_123', 'object': 'customer', 'email': 'a@b.com'},
        'subscription': {'id': 'sub_123', 'object': 'subscription'},
      });

      expect(session.customer!.isExpanded, isTrue);
      expect(session.customer!.value!.email, 'a@b.com');
      expect(session.subscription!.isExpanded, isTrue);
      expect(session.subscription!.value!.id, 'sub_123');
    });

    test('leaves customer and subscription null when absent', () {
      final session = CheckoutSession.fromJson(
          {'id': 'cs_123', 'object': 'checkout.session'});

      expect(session.customer, isNull);
      expect(session.subscription, isNull);
    });

    test('throws when id is missing', () {
      expect(
        () => CheckoutSession.fromJson(<String, Object?>{}),
        throwsA(isA<Object>()),
      );
    });

    test('toString summarises id, mode and status', () {
      const session =
          CheckoutSession(id: 'cs_123', mode: 'payment', status: 'open');
      expect(
        session.toString(),
        'CheckoutSession(id: cs_123, mode: payment, status: open)',
      );
    });
  });

  group('StripeClient.checkout.sessions.create', () {
    test('encodes the indexed line_items and discounts arrays', () async {
      http.Request? captured;
      final client = StripeClient(
        apiKey: 'sk_test_123',
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'id': 'cs_123',
              'object': 'checkout.session',
              'url': 'https://checkout.stripe.com/pay/cs_123',
            }),
            200,
          );
        }),
      );

      final session = await client.checkout.sessions.create(
        const CheckoutSessionCreateParams(
          mode: CheckoutSessionMode.subscription,
          lineItems: [
            CheckoutSessionLineItemParams(price: 'price_123', quantity: 1),
          ],
          successUrl: 'https://example.com/success',
          cancelUrl: 'https://example.com/cancel',
          discounts: [
            CheckoutSessionDiscountParams(promotionCode: 'promo_123'),
          ],
        ),
      );

      expect(session.id, 'cs_123');
      expect(captured!.method, 'POST');
      expect(captured!.url.path, '/v1/checkout/sessions');
      expect(
        captured!.body,
        'mode=subscription'
        '&line_items[0][price]=price_123&line_items[0][quantity]=1'
        '&success_url=https%3A%2F%2Fexample.com%2Fsuccess'
        '&cancel_url=https%3A%2F%2Fexample.com%2Fcancel'
        '&discounts[0][promotion_code]=promo_123',
      );
    });
  });
}
