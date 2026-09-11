// Captures test/fixtures/error_golden.json from the real stripe-node client
// (not hand-written) by driving it through its `httpClient` injection seam
// with canned HTTP responses. Run from the main Fullphysio checkout, where
// stripe-node is actually installed:
//
//   cd /Users/ortes/Documents/Fullphysio/fullphysio/functions/js
//   node /Users/ortes/Documents/Fullphysio/stripe_client/tool/capture_fixtures/errors.js
//
// `require('stripe')` is resolved against the current working directory (see
// loadStripe below), which is why the invocation above must `cd` there first.

'use strict';

const fs = require('fs');
const path = require('path');

const STRIPE_NODE_VERSION = '19.3.1';

function loadStripe() {
  let resolved;
  try {
    resolved = require.resolve('stripe', { paths: [process.cwd()] });
  } catch (e) {
    throw new Error(
      'Could not resolve the "stripe" package from ' +
        process.cwd() +
        '. Run this script with the Fullphysio functions/js checkout as the ' +
        'working directory, e.g.:\n' +
        '  cd /Users/ortes/Documents/Fullphysio/fullphysio/functions/js\n' +
        '  node ' +
        __filename
    );
  }
  return require(resolved);
}

const Stripe = loadStripe();

function fakeFetchReturning(status, body, headers) {
  return () =>
    Promise.resolve(
      new Response(typeof body === 'string' ? body : JSON.stringify(body), {
        status,
        headers,
      })
    );
}

function clientFor(statusCode, body, headers) {
  return Stripe('sk_test_capture_fixture', {
    httpClient: Stripe.createFetchHttpClient(fakeFetchReturning(statusCode, body, headers)),
    maxNetworkRetries: 0,
  });
}

function orNull(value) {
  return value === undefined ? null : value;
}

async function driveStripeNode(statusCode, body, headers) {
  const stripe = clientFor(statusCode, body, headers);
  try {
    await stripe.charges.retrieve('ch_capture_fixture');
    return { threw: false };
  } catch (err) {
    return {
      threw: true,
      className: err.constructor.name,
      message: orNull(err.message),
      code: orNull(err.code),
      type: orNull(err.rawType),
      statusCode: orNull(err.statusCode),
      requestId: orNull(err.requestId),
      param: orNull(err.param),
      docUrl: orNull(err.doc_url),
      detail: orNull(err.detail),
      charge: orNull(err.charge),
      declineCode: orNull(err.decline_code),
      paymentIntent: orNull(err.payment_intent),
      paymentMethod: orNull(err.payment_method),
      paymentMethodType: orNull(err.payment_method_type),
      setupIntent: orNull(err.setup_intent),
      source: orNull(err.source),
      userMessage: orNull(err.userMessage),
      headers: orNull(err.headers),
    };
  }
}

function rawErrorOf(body) {
  if (body !== null && typeof body === 'object' && Object.prototype.hasOwnProperty.call(body, 'error')) {
    return body.error;
  }
  return null;
}

async function makeCase(name, options) {
  const statusCode = options.statusCode;
  const body = options.body;
  const headers = Object.assign({ 'content-type': 'application/json', 'request-id': 'req_123' }, options.headers);
  const stripeNode = await driveStripeNode(statusCode, body, headers);
  const expected = options.expectedOverride || stripeNode;
  return {
    name,
    note: options.note || null,
    input: {
      statusCode,
      body,
      headers,
      requestId: headers['request-id'],
    },
    rawError: rawErrorOf(body),
    stripeNode,
    expected,
  };
}

async function main() {
  const cases = [];

  cases.push(
    await makeCase('card_error_type', {
      statusCode: 400,
      body: { error: { type: 'card_error', message: 'Your card was declined.', code: 'card_declined' } },
    })
  );

  cases.push(
    await makeCase('invalid_request_error_type', {
      statusCode: 400,
      body: { error: { type: 'invalid_request_error', message: 'Missing a required param.' } },
    })
  );

  cases.push(
    await makeCase('api_error_type', {
      statusCode: 400,
      body: { error: { type: 'api_error', message: 'Something went wrong on our end.' } },
    })
  );

  cases.push(
    await makeCase('authentication_error_type', {
      statusCode: 400,
      body: { error: { type: 'authentication_error', message: 'Invalid API key provided.' } },
    })
  );

  cases.push(
    await makeCase('rate_limit_error_type', {
      statusCode: 400,
      body: { error: { type: 'rate_limit_error', message: 'Too many requests hit the API too quickly.' } },
    })
  );

  cases.push(
    await makeCase('idempotency_error_type', {
      statusCode: 400,
      body: {
        error: {
          type: 'idempotency_error',
          message: 'Keys for idempotent requests can only be used with the same parameters they were first used with.',
        },
      },
    })
  );

  cases.push(
    await makeCase('invalid_grant_type', {
      statusCode: 400,
      body: { error: { type: 'invalid_grant', message: 'This authorization code has already been used.' } },
    })
  );

  cases.push(
    await makeCase('unknown_type_falls_back', {
      statusCode: 400,
      body: { error: { type: 'a_type_this_client_has_never_heard_of', message: 'From the future.' } },
    })
  );

  cases.push(
    await makeCase('status_401_overrides_card_error_type', {
      statusCode: 401,
      body: {
        error: { type: 'card_error', message: 'Would be a card error if type were consulted.', code: 'card_declined' },
      },
      note:
        "HTTP 401 short-circuits to StripeAuthenticationError before the body's `type` is ever consulted, " +
        'even though the body claims to be a card_error. This is the precedence trap: status beats type.',
    })
  );

  cases.push(
    await makeCase('status_403_overrides_invalid_request_error_type', {
      statusCode: 403,
      body: {
        error: { type: 'invalid_request_error', message: 'Would be an invalid_request_error if type were consulted.' },
      },
      note: "HTTP 403 short-circuits to StripePermissionError before the body's `type` is ever consulted.",
    })
  );

  cases.push(
    await makeCase('status_429_overrides_api_error_type', {
      statusCode: 429,
      body: { error: { type: 'api_error', message: 'Would be an api_error if type were consulted.' } },
      note: "HTTP 429 short-circuits to StripeRateLimitError before the body's `type` is ever consulted.",
    })
  );

  cases.push(
    await makeCase('card_error_402_with_decline_code_and_charge', {
      statusCode: 402,
      body: {
        error: {
          type: 'card_error',
          message: 'Your card was declined.',
          code: 'card_declined',
          decline_code: 'insufficient_funds',
          charge: 'ch_capture_fixture_charge',
          payment_intent: { id: 'pi_capture_fixture', object: 'payment_intent', status: 'requires_payment_method' },
          payment_method: { id: 'pm_capture_fixture', object: 'payment_method', type: 'card' },
        },
      },
    })
  );

  cases.push(
    await makeCase('invalid_request_400_with_param_and_doc_url', {
      statusCode: 400,
      body: {
        error: {
          type: 'invalid_request_error',
          message: 'Missing required param: customer.',
          param: 'customer',
          doc_url: 'https://stripe.com/docs/error-codes#parameter-missing',
        },
      },
    })
  );

  cases.push(
    await makeCase('api_error_500', {
      statusCode: 500,
      body: { error: { type: 'api_error', message: 'An error occurred with our API.' } },
    })
  );

  cases.push(
    await makeCase('empty_body', {
      statusCode: 500,
      body: '',
    })
  );

  cases.push(
    await makeCase('non_json_body', {
      statusCode: 502,
      body: '<html><body>Bad Gateway</body></html>',
      headers: { 'content-type': 'text/html' },
    })
  );

  cases.push(
    await makeCase('no_error_key', {
      statusCode: 400,
      body: { foo: 'bar' },
      note:
        "stripe-node treats a body with no `error` key as a successful response and never constructs an " +
        "error at all (see stripeNode.threw: false above). stripe_client's stripeErrorFromResponse is only " +
        'ever invoked once the caller already knows the response failed (typically via a non-2xx status), ' +
        'so it cannot special-case "not actually an error" -- it falls back to the same handling as an ' +
        'undecodable body, below.',
      expectedOverride: {
        threw: true,
        className: 'StripeAPIError',
        message: 'Invalid JSON received from the Stripe API',
        code: null,
        type: null,
        statusCode: null,
        requestId: 'req_123',
        param: null,
        docUrl: null,
        detail: null,
        charge: null,
        declineCode: null,
        paymentIntent: null,
        paymentMethod: null,
        paymentMethodType: null,
        setupIntent: null,
        source: null,
        userMessage: null,
        headers: null,
      },
    })
  );

  cases.push(
    await makeCase('all_remaining_fields_pass_through', {
      statusCode: 400,
      body: {
        error: {
          type: 'invalid_request_error',
          message: 'Illustrative error exercising every remaining field.',
          detail: 'Some additional detail text.',
          user_message: 'A message safe to show your customer.',
          payment_method_type: 'card',
          setup_intent: { id: 'seti_capture_fixture', object: 'setup_intent', status: 'requires_payment_method' },
          source: { id: 'src_capture_fixture', object: 'source', type: 'card' },
        },
      },
    })
  );

  const fixture = {
    capturedFrom: { package: 'stripe', version: STRIPE_NODE_VERSION },
    seam: 'Stripe.createFetchHttpClient(fetchFn) injected as the `httpClient` client option',
    cases,
  };

  const outPath = path.join(__dirname, '..', '..', 'test', 'fixtures', 'error_golden.json');
  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, JSON.stringify(fixture, null, 2) + '\n');
  console.log('Wrote ' + cases.length + ' cases to ' + outPath);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
