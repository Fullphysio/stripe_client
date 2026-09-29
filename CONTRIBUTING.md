# Contributing

## Reporting a bug

Open an issue with the package version, the call you made, and what Stripe
returned (redact keys and personal data). A failing request is most useful
with its HTTP status and the exception's message.

Behaviour follows the official `stripe-node` client. If this package differs from it,
that is a bug unless the README lists it as a deliberate divergence.

## Running the tests

```
dart pub get
dart analyze --fatal-infos
dart test                      # unit and golden conformance, no network
```

## Adding an operation

The resources in `lib/src/resources/` are hand-written against the vendored
OpenAPI spec in `tool/spec/`. Adding a missing operation is usually one
resource method, one params class and a golden fixture — open an issue first
so we can agree on the shape.

## Pull requests

- Keep `dart format` (default width) and `dart analyze --fatal-infos` clean.
- Every exported symbol needs `///` dartdoc.
- Add a `CHANGELOG.md` entry under an `## Unreleased` heading.
