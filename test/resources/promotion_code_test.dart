import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stripe_client/src/core/expand_params.dart';
import 'package:stripe_client/src/resources/promotion_code.dart';
import 'package:stripe_client/src/transport/stripe_client.dart';
import 'package:test/test.dart';

void main() {
  group('PromotionCodePromotion.fromJson', () {
    test('decodes the nested coupon and type', () {
      final promotion = PromotionCodePromotion.fromJson({
        'type': 'coupon',
        'coupon': {'id': 'coupon_123', 'object': 'coupon', 'amount_off': 500},
      });

      expect(promotion.type, 'coupon');
      expect(promotion.coupon.isExpanded, isTrue);
      expect(promotion.coupon.value!.amountOff, 500);
    });

    test('decodes a bare coupon id when unexpanded', () {
      final promotion = PromotionCodePromotion.fromJson(
          {'type': 'coupon', 'coupon': 'coupon_123'});
      expect(promotion.coupon.isExpanded, isFalse);
      expect(promotion.coupon.id, 'coupon_123');
    });

    test('toString summarises coupon and type', () {
      final promotion = PromotionCodePromotion.fromJson(
          {'type': 'coupon', 'coupon': 'coupon_123'});
      expect(
        promotion.toString(),
        'PromotionCodePromotion(coupon: Expandable<Coupon>.id(coupon_123), '
        'type: coupon)',
      );
    });
  });

  group('PromotionCodeRestrictions.fromJson', () {
    test('decodes every restriction field', () {
      final restrictions = PromotionCodeRestrictions.fromJson({
        'first_time_transaction': true,
        'minimum_amount': 5000,
        'minimum_amount_currency': 'usd',
      });

      expect(restrictions.firstTimeTransaction, isTrue);
      expect(restrictions.minimumAmount, 5000);
      expect(restrictions.minimumAmountCurrency, 'usd');
    });

    test('leaves fields null when absent', () {
      final restrictions =
          PromotionCodeRestrictions.fromJson(<String, Object?>{});
      expect(restrictions.firstTimeTransaction, isNull);
      expect(restrictions.minimumAmount, isNull);
      expect(restrictions.minimumAmountCurrency, isNull);
    });

    test('toString summarises the fields', () {
      const restrictions =
          PromotionCodeRestrictions(firstTimeTransaction: true);
      expect(
        restrictions.toString(),
        'PromotionCodeRestrictions(firstTimeTransaction: true, '
        'minimumAmount: null)',
      );
    });
  });

  group('PromotionCode.fromJson', () {
    test('decodes the nested promotion.coupon shape', () {
      final promotionCode = PromotionCode.fromJson({
        'id': 'promo_123',
        'object': 'promotion_code',
        'code': 'SAVE10',
        'active': true,
        'times_redeemed': 3,
        'max_redemptions': 10,
        'expires_at': 1731600000,
        'promotion': {
          'type': 'coupon',
          'coupon': {
            'id': 'coupon_123',
            'object': 'coupon',
            'percent_off': 10.0
          },
        },
        'restrictions': {'first_time_transaction': false},
        'customer': 'cus_123',
      });

      expect(promotionCode.id, 'promo_123');
      expect(promotionCode.code, 'SAVE10');
      expect(promotionCode.active, isTrue);
      expect(promotionCode.timesRedeemed, 3);
      expect(promotionCode.maxRedemptions, 10);
      expect(promotionCode.expiresAt, isNotNull);
      expect(promotionCode.coupon!.id, 'coupon_123');
      expect(promotionCode.coupon!.percentOff, 10.0);
      expect(promotionCode.restrictions!.firstTimeTransaction, isFalse);
      expect(promotionCode.customer!.isExpanded, isFalse);
      expect(promotionCode.customer!.id, 'cus_123');
    });

    test('decodes an expanded customer', () {
      final promotionCode = PromotionCode.fromJson({
        'id': 'promo_123',
        'object': 'promotion_code',
        'customer': {'id': 'cus_123', 'object': 'customer', 'email': 'a@b.com'},
      });

      expect(promotionCode.customer!.isExpanded, isTrue);
      expect(promotionCode.customer!.value!.email, 'a@b.com');
    });

    test('coupon getter returns null when promotion is absent', () {
      final promotionCode = PromotionCode.fromJson(
          {'id': 'promo_123', 'object': 'promotion_code'});

      expect(promotionCode.promotion, isNull);
      expect(promotionCode.coupon, isNull);
      expect(promotionCode.customer, isNull);
      expect(promotionCode.restrictions, isNull);
    });

    test('throws when id is missing', () {
      expect(
        () => PromotionCode.fromJson(<String, Object?>{}),
        throwsA(isA<Object>()),
      );
    });

    test('toString summarises id, code and active', () {
      const promotionCode =
          PromotionCode(id: 'promo_123', code: 'SAVE10', active: true);
      expect(
        promotionCode.toString(),
        'PromotionCode(id: promo_123, code: SAVE10, active: true)',
      );
    });
  });

  group('PromotionCodeCreateParams.toJson', () {
    test('nests coupon under the promotion object, hiding type', () {
      const params = PromotionCodeCreateParams(coupon: 'coupon_123');
      expect(params.toJson(), {
        'promotion': {'type': 'coupon', 'coupon': 'coupon_123'},
      });
    });

    test('encodes every optional field when given', () {
      final expiresAt = DateTime.utc(2027, 1, 1);
      final params = PromotionCodeCreateParams(
        coupon: 'coupon_123',
        code: 'SAVE10',
        customer: 'cus_123',
        active: false,
        maxRedemptions: 5,
        expiresAt: expiresAt,
        metadata: const {'source': 'campaign'},
      );

      expect(params.toJson(), {
        'promotion': {'type': 'coupon', 'coupon': 'coupon_123'},
        'code': 'SAVE10',
        'customer': 'cus_123',
        'active': false,
        'max_redemptions': 5,
        'expires_at': expiresAt,
        'metadata': {'source': 'campaign'},
      });
    });

    test('toString summarises coupon and code', () {
      const params =
          PromotionCodeCreateParams(coupon: 'coupon_123', code: 'SAVE10');
      expect(
        params.toString(),
        'PromotionCodeCreateParams(coupon: coupon_123, code: SAVE10)',
      );
    });
  });

  group('PromotionCodeListParams.toJson', () {
    test('omits every field when none is given', () {
      const params = PromotionCodeListParams();
      expect(params.toJson(), isEmpty);
    });

    test('encodes every field when given', () {
      const params = PromotionCodeListParams(
        code: 'SAVE10',
        active: true,
        limit: 5,
        customer: 'cus_123',
        expand: ['customer'],
      );

      expect(params.toJson(), {
        'code': 'SAVE10',
        'active': true,
        'limit': 5,
        'customer': 'cus_123',
        'expand': ['customer'],
      });
    });

    test('toString summarises code, active and customer', () {
      const params = PromotionCodeListParams(code: 'SAVE10', active: true);
      expect(
        params.toString(),
        'PromotionCodeListParams(code: SAVE10, active: true, customer: null)',
      );
    });
  });

  group('StripeClient.promotionCodes', () {
    test('create sends the nested promotion body to POST /v1/promotion_codes',
        () async {
      http.Request? captured;
      final client = StripeClient(
        apiKey: 'sk_test_123',
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'id': 'promo_123',
              'object': 'promotion_code',
              'promotion': {'type': 'coupon', 'coupon': 'coupon_123'},
            }),
            200,
          );
        }),
      );

      final promotionCode = await client.promotionCodes.create(
        const PromotionCodeCreateParams(coupon: 'coupon_123'),
      );

      expect(promotionCode.id, 'promo_123');
      expect(captured!.method, 'POST');
      expect(captured!.url.path, '/v1/promotion_codes');
      expect(
        captured!.body,
        'promotion[type]=coupon&promotion[coupon]=coupon_123',
      );
    });

    test('retrieve sends a GET to /v1/promotion_codes/{id} with expand',
        () async {
      http.Request? captured;
      final client = StripeClient(
        apiKey: 'sk_test_123',
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({'id': 'promo_123', 'object': 'promotion_code'}),
            200,
          );
        }),
      );

      await client.promotionCodes
          .retrieve('promo_123', const ExpandParams(expand: ['customer']));

      expect(captured!.method, 'GET');
      expect(captured!.url.path, '/v1/promotion_codes/promo_123');
      expect(captured!.url.query, 'expand%5B0%5D=customer');
    });

    test('list sends a GET to /v1/promotion_codes and returns a StripeList',
        () async {
      http.Request? captured;
      final client = StripeClient(
        apiKey: 'sk_test_123',
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'object': 'list',
              'has_more': false,
              'url': '/v1/promotion_codes',
              'data': [
                {'id': 'promo_123', 'object': 'promotion_code'},
              ],
            }),
            200,
          );
        }),
      );

      final list = await client.promotionCodes.list(
        const PromotionCodeListParams(active: true),
      );

      expect(list.data, hasLength(1));
      expect(list.data.first.id, 'promo_123');
      expect(captured!.method, 'GET');
      expect(captured!.url.path, '/v1/promotion_codes');
      expect(captured!.url.query, 'active=true');
    });
  });
}
