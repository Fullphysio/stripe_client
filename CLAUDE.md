# Conventions

This is a public package, so it does **not** follow the Fullphysio monorepo's
no-comments or 120-column rules.

- `///` dartdoc is **required** on every exported symbol. pub.dev scores it and
  IDE hovers depend on it.
- No comments on private implementation code. Name things properly instead.
- Formatting is stock `dart format` — **default width, no `--line-length`**.
  That is what `pana` and pub.dev expect with zero configuration.
  A Dart SDK from a Flutter fork or a dev channel can format differently from
  stable; CI runs official stable and is the arbiter.
- `dart analyze --fatal-infos` must be clean.

## Layout

- `lib/src/` — the hand-written runtime core, ported from `stripe-node`.
- `lib/src/core/` — hand-written support types the generated code imports
  (`Expandable`, `StripeList`, tolerant JSON readers, exceptions).
- `lib/src/{models,params,services}/` — **generated, committed**. Never edit by
  hand; change the generator or the allowlist and regenerate.
- `lib/src/transport/` — hand-written, permanent runtime (HTTP transport,
  retry policy): never touched by a future generator, unlike the layer below.
- `lib/src/resources/` — hand-written resources shipped before the generator
  exists. Interim and disposable, not a permanent layer: each resource moves
  out into `lib/src/{services,params,models}/` once the generator lands, so
  this directory shrinks rather than grows. Kept separate from
  `lib/src/{models,params,services}/` specifically so a future generator run
  (and its `--check` drift job) never has hand-written code in its way.
- `tool/` — the generator and the vendored OpenAPI spec.

## Codegen

Output is committed. There is no `build_runner` — consumers must not need a
build step.

```
dart run tool/generate.dart            # regenerate
dart run tool/generate.dart --check    # CI: fail on drift
```

Bump the spec with `dart run tool/spec/update_spec.dart --tag vNNNN`. Pick the
tag by reading the `OPENAPI_VERSION` file of the `stripe-node` release you want
to track — do not track `master`.

A regenerate is not reviewable as a text diff. The generator emits a semantic
`CHANGELOG_SPEC.md` fragment (added/removed schemas, enum values, required
fields); **that** is the reviewed artifact.

## CI jobs that are deliberately not here yet

Each of these fails if added before its prerequisite exists, so each lands with
the thing it checks. Do not add them back early.

| Job | Blocked on | Why it fails today |
|---|---|---|
| `codegen` (`tool/generate.dart --check`) | the generator | the script does not exist |
| `stripe_mock` (`--tags stripe_mock`) | stripe-mock round-trip tests | `dart test` exits 79 when no test carries the tag |
| `integration.yml` | `test/integration/` | same exit 79 |

## Tests

Three tiers:

- **Unit and golden conformance** — the default `dart test` run. No network.
  Fixtures in `test/fixtures/*.json` were captured from the real `stripe-node`
  (19.3.1) through its own `httpClient` injection seam. When changing request
  construction, regenerate the fixtures against the same reference version
  rather than editing them by hand, and bump the version recorded in
  `THIRD_PARTY_NOTICES` and the README if you move to a newer upstream.
- **stripe-mock** (`--tags stripe_mock`) — Stripe's official local mock. Real
  sockets, spec-validated, no account and no network, so it runs on every PR.
  Self-skips when `STRIPE_MOCK_HOST` is unset.
- **Integration** (`test/integration/`, `--tags integration`) — hits the live
  Stripe API in test mode. Self-skips when `STRIPE_TEST_SECRET_KEY` is unset, so
  a fresh checkout passes. Never runs on pull requests.

Assertions are structural. Never assert on how much data an account holds, or
the suite rots.

## Conformance with stripe-node

This package reproduces `stripe-node` 19.3.1 behaviour deliberately, including
quirks. Before "fixing" something that looks wrong, check the reference — if the
JS does it, we do it, and the reason belongs in a test name, not a code comment.

The traps that already cost time:

- `Content-Type: application/x-www-form-urlencoded` is sent on **every** v1
  request, including bodyless GET and DELETE. Only `Content-Length` is gated on
  the method.
- The form encoder follows `qs` with `arrayFormat: 'indices'` and the **RFC3986**
  unreserved set (`-._~` + alphanumerics). It escapes `! * ' ( )` and renders
  space as `%20`. Neither `Uri.encodeComponent` nor `Uri.encodeQueryComponent`
  matches, and neither does `sanity_api`'s encoder, which implements the WHATWG
  form-urlencoded variant on purpose.
- Empty containers vanish from the wire recursively. `{a: {b: []}}` sends
  nothing at all, not even `a`.
- HTTP 401/403/429 pick the error class **before** the response body's `type`
  field is consulted.
- A present `null` serialises as `key=` (empty value); an absent key sends
  nothing. Do not collapse the two.
- `tolerance <= 0` on webhook verification **disables** the timestamp check.

## Releasing

1. Bump `version:` in `pubspec.yaml` and add a `CHANGELOG.md` entry.
2. Merge to `main` and let CI go green.
3. Tag and push:

   ```
   git tag v1.2.3 && git push origin v1.2.3
   ```

Publishing is permanent: a version can be retracted within 7 days but never
deleted, and the number is never reusable. The `description:` in `pubspec.yaml`
must stay at or under 180 characters or pana drops the score.
