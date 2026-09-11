// Demonstrates the parts of stripe_client that are stable today: the error
// hierarchy every request can raise, and the decoding primitives the
// generated model layer is built on.
//
// Run with: dart run example/stripe_client_example.dart

import 'package:stripe_client/stripe_client.dart';

void main() {
  _handlingErrors();
  _readingExpandableFields();
  _readingFieldsTolerantly();
}

/// Errors form a sealed hierarchy, so a `switch` covers every case the API can
/// return and the compiler tells you when one is missed.
void _handlingErrors() {
  final errors = <StripeError>[
    const StripeCardError(
      message: 'Your card was declined.',
      code: 'card_declined',
      declineCode: 'insufficient_funds',
    ),
    const StripeRateLimitError(message: 'Too many requests.'),
    StripeConnectionError('Could not reach Stripe.'),
  ];

  for (final error in errors) {
    final advice = switch (error) {
      StripeCardError(:final declineCode) =>
        'Ask for another card ($declineCode).',
      StripeRateLimitError() => 'Back off and retry.',
      StripeConnectionError() => 'Retry: the request never reached Stripe.',
      StripeInvalidRequestError() => 'Fix the request parameters.',
      StripeAuthenticationError() => 'Check the API key.',
      StripePermissionError() => 'The key lacks access to this resource.',
      StripeIdempotencyError() => 'Reuse of a key with different parameters.',
      StripeInvalidGrantError() => 'The OAuth grant is no longer valid.',
      StripeSignatureVerificationError() => 'Reject the webhook delivery.',
      StripeAPIError() => 'Stripe had a problem; retry later.',
      StripeUnknownError() => 'Unrecognised error type; log and investigate.',
    };
    print('${error.runtimeType}: $advice');
  }
}

/// Many Stripe fields hold either a bare id or the full object, depending on
/// whether the request expanded them. [Expandable] models both without forcing
/// a null check on the id.
void _readingExpandableFields() {
  final unexpanded = Expandable<StripeStub>.fromJson(
    'in_1234',
    StripeStub.fromJson,
    StripeStub.idOf,
    fieldName: 'subscription.latest_invoice',
  );

  final expanded = Expandable<StripeStub>.fromJson(
    {'id': 'in_1234', 'object': 'invoice', 'amount_paid': 4900},
    StripeStub.fromJson,
    StripeStub.idOf,
    fieldName: 'subscription.latest_invoice',
  );

  // The id is available either way, so call sites that only need it never
  // have to care whether the request expanded the field.
  print('${unexpanded.id} expanded=${unexpanded.isExpanded}');
  print('${expanded.id} expanded=${expanded.isExpanded}');
  print('amount paid: ${expanded.value?.raw['amount_paid']}');
}

/// Reading a payload is deliberately permissive. Stripe adds fields without
/// notice and removes them across API versions, so an absent or unexpected
/// value yields null rather than throwing.
void _readingFieldsTolerantly() {
  const payload = <String, Object?>{
    'id': 'sub_1234',
    'object': 'subscription',
    'created': 1731600000,
    'metadata': {'plan': 'annual'},
    'cancel_at_period_end': null,
    // Moved to the subscription item in API version 2025-03-31.basil, so it
    // is simply absent here rather than an error.
    // 'current_period_end': ...,
  };

  print(payload.requireString('id', 'subscription'));
  print(payload.optUnixTime('created')?.toIso8601String());
  print(payload.optStringMap('metadata'));
  print('cancel_at_period_end: ${payload.optBool('cancel_at_period_end')}');
  print('current_period_end: ${payload.optUnixTime('current_period_end')}');
}
