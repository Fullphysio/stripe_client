/// A pure Dart client for the Stripe API.
///
/// Typed resources, webhook signature verification, automatic retries and
/// idempotency keys, from Dart servers, CLIs and Flutter apps alike. No
/// Flutter dependency.
///
/// The runtime behaviour is a deliberate port of the official Node client,
/// `stripe-node` 19.3.1 — retry policy, backoff, idempotency-key generation,
/// webhook signature verification and error mapping all follow that
/// implementation. Typed models are written against Stripe's OpenAPI
/// specification at revision v2111, vendored in the repository.
library;

export 'src/core/exceptions.dart' show StripeDecodeException;
export 'src/core/expand_params.dart' show ExpandParams;
export 'src/core/expandable.dart' show Expandable, StripeStub;
export 'src/core/json_reading.dart' show StripeJsonReading;
export 'src/core/stripe_list.dart' show StripeList;
export 'src/errors.dart'
    show
        StripeAPIError,
        StripeAuthenticationError,
        StripeCardError,
        StripeConnectionError,
        StripeError,
        StripeIdempotencyError,
        StripeInvalidGrantError,
        StripeInvalidRequestError,
        StripePermissionError,
        StripeRateLimitError,
        StripeSignatureVerificationError,
        StripeUnknownError;
export 'src/resources/billing_portal_session.dart'
    show BillingPortalSession, BillingPortalSessionCreateParams;
export 'src/resources/checkout_session.dart'
    show
        CheckoutSession,
        CheckoutSessionAutomaticTaxParams,
        CheckoutSessionCreateParams,
        CheckoutSessionCustomerUpdateParams,
        CheckoutSessionDiscountParams,
        CheckoutSessionLineItemParams,
        CheckoutSessionMode,
        CheckoutSessionPhoneNumberCollectionParams,
        CheckoutSessionSubscriptionDataParams,
        CheckoutSessionTaxIdCollectionParams;
export 'src/resources/coupon.dart' show Coupon;
export 'src/resources/customer.dart'
    show
        Customer,
        CustomerBalanceTransaction,
        CustomerCreateBalanceTransactionParams,
        CustomerUpdateParams;
export 'src/resources/discount.dart' show Discount, DiscountSource;
export 'src/resources/event.dart' show Event, EventData;
export 'src/resources/invoice.dart'
    show
        Invoice,
        InvoiceDiscountAmount,
        InvoiceLineItem,
        InvoiceTaxAmount,
        InvoiceTotalTax,
        InvoiceTotalTaxRateDetails;
export 'src/resources/plan.dart' show Plan;
export 'src/resources/price.dart' show Price, PriceRecurring;
export 'src/resources/product.dart' show Product;
export 'src/resources/promotion_code.dart'
    show
        PromotionCode,
        PromotionCodeCreateParams,
        PromotionCodeListParams,
        PromotionCodePromotion,
        PromotionCodeRestrictions;
export 'src/resources/subscription.dart'
    show Subscription, SubscriptionItem, SubscriptionListParams;
export 'src/transport/stripe_client.dart' show StripeClient;
export 'src/webhooks.dart' show StripeWebhooks;

// Internal plumbing stays unexported: form encoding, crypto helpers, retry
// policy and the namespace/service wiring behind StripeClient are
// implementation detail, not API. Generated models are added here as that
// module lands.
