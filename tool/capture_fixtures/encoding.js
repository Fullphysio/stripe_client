'use strict';

// Captures the exact wire-format strings that stripe-node 19.3.1 produces for
// its v1 request encoder (qs.stringify with arrayFormat: 'indices'), using the
// SDK's own httpClient injection seam. No network, no account.
//
// Must be run with the main fullphysio checkout's functions/js as the working
// directory, so that the bare `stripe` module resolves against its installed
// node_modules:
//
//   cd /Users/ortes/Documents/Fullphysio/fullphysio/functions/js
//   node /Users/ortes/Documents/Fullphysio/stripe_client/tool/capture_fixtures/encoding.js

const path = require('path');
const fs = require('fs');

const Stripe = require(path.join(process.cwd(), 'node_modules', 'stripe'));

let captured = [];

function fakeFetch(url, init) {
  captured.push({
    url: url.toString(),
    method: init.method,
    body: init.body ?? null,
  });
  return Promise.resolve(
    new Response(JSON.stringify({ id: 'stub', object: 'stub' }), {
      status: 200,
      headers: { 'content-type': 'application/json' },
    }),
  );
}

const stripe = new Stripe('sk_test_123', {
  httpClient: Stripe.createFetchHttpClient(fakeFetch),
  maxNetworkRetries: 0,
});

function wireStringFromCapturedRequest(entry) {
  if (entry.body !== null && entry.body !== undefined) {
    return entry.body;
  }
  const queryIndex = entry.url.indexOf('?');
  return queryIndex === -1 ? '' : entry.url.slice(queryIndex + 1);
}

async function capture(results, name, exercise) {
  captured = [];
  await exercise();
  if (captured.length !== 1) {
    throw new Error(
      `case "${name}" expected exactly one request, got ${captured.length}`,
    );
  }
  results[name] = wireStringFromCapturedRequest(captured[0]);
}

async function main() {
  const results = {};

  await capture(results, 'flatScalars', () =>
    stripe.customers.update('cus_123', {
      name: 'Ada Lovelace',
      description: 'First customer',
      phone: '+14155552671',
    }),
  );

  await capture(results, 'nestedObject', () =>
    stripe.customers.update('cus_123', {
      address: {
        line1: '1 Infinite Loop',
        city: 'Cupertino',
        country: 'US',
      },
    }),
  );

  await capture(results, 'deeplyNested', () =>
    stripe.checkout.sessions.create({
      mode: 'payment',
      success_url: 'https://example.com/success',
      payment_intent_data: {
        shipping: {
          address: {
            line1: '1 Infinite Loop',
            city: 'Cupertino',
            country: 'US',
          },
        },
      },
    }),
  );

  await capture(results, 'arrayOfScalars', () =>
    stripe.checkout.sessions.create({
      mode: 'payment',
      success_url: 'https://example.com/success',
      payment_method_types: ['card', 'ideal', 'bancontact'],
    }),
  );

  await capture(results, 'arrayOfObjects', () =>
    stripe.checkout.sessions.create({
      mode: 'payment',
      success_url: 'https://example.com/success',
      line_items: [
        { price: 'price_123', quantity: 1 },
        { price: 'price_456', quantity: 2 },
      ],
    }),
  );

  await capture(results, 'emptyArray', () =>
    stripe.checkout.sessions.create({
      mode: 'payment',
      success_url: 'https://example.com/success',
      payment_method_types: [],
    }),
  );

  await capture(results, 'emptyObject', () =>
    stripe.customers.update('cus_123', {
      name: 'Empty Object Test',
      metadata: {},
    }),
  );

  await capture(results, 'nestedEmptyCascade', () =>
    stripe.customers.update('cus_123', {
      invoice_settings: { custom_fields: [] },
    }),
  );

  await capture(results, 'presentNull', () =>
    stripe.customers.update('cus_123', { description: null }),
  );

  await capture(results, 'booleanTrue', () =>
    stripe.checkout.sessions.create({
      mode: 'payment',
      success_url: 'https://example.com/success',
      allow_promotion_codes: true,
    }),
  );

  await capture(results, 'booleanFalse', () =>
    stripe.subscriptions.update('sub_123', { cancel_at_period_end: false }),
  );

  await capture(results, 'wholeNumber', () =>
    stripe.subscriptions.list({ limit: 25 }),
  );

  await capture(results, 'negativeNumber', () =>
    stripe.customers.update('cus_123', { balance: -1500 }),
  );

  await capture(results, 'dateNormal', () =>
    stripe.subscriptions.list({ created: new Date('2024-01-15T10:30:00.000Z') }),
  );

  await capture(results, 'dateBeforeEpoch', () =>
    stripe.subscriptions.list({
      created: new Date('1969-12-31T23:59:59.500Z'),
    }),
  );

  await capture(results, 'unicodeString', () =>
    stripe.customers.update('cus_123', { name: 'Zoë Åström 中文 😀' }),
  );

  await capture(results, 'specialCharsString', () =>
    stripe.customers.update('cus_123', {
      description: "a!b*c'd(e)f~g h&i=j[k]l",
    }),
  );

  await capture(results, 'expandDottedPaths', () =>
    stripe.subscriptions.list({
      expand: ['data.default_payment_method', 'data.latest_invoice.payment_intent'],
    }),
  );

  const outPath = path.join(__dirname, '..', '..', 'test', 'fixtures', 'encoding_golden.json');
  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, JSON.stringify(results, null, 2) + '\n');
  console.log(`Wrote ${Object.keys(results).length} cases to ${outPath}`);
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
