import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// Fetches `openapi/spec3.sdk.json` from `stripe/openapi` at a given tag and
/// vendors it into `tool/spec/`, recording its digest and version.
///
/// Usage: `dart run tool/spec/update_spec.dart --tag vNNNN`
///
/// The tag is never chosen automatically. Pick it by reading the
/// `OPENAPI_VERSION` file of the `stripe-node` release this package tracks —
/// that is a human decision recorded in a PR, not something this script
/// infers.
Future<void> main(List<String> arguments) async {
  final String tag = _parseTag(arguments);
  final Uri url = Uri.parse(
    'https://raw.githubusercontent.com/stripe/openapi/$tag/openapi/spec3.sdk.json',
  );

  final http.Response response = await http.get(url);
  if (response.statusCode != 200) {
    throw StateError(
      'Failed to download spec for tag "$tag" from $url: '
      'HTTP ${response.statusCode}. Confirm the tag exists in '
      'https://github.com/stripe/openapi/tags.',
    );
  }

  final List<int> bytes = response.bodyBytes;
  final Object? decoded = _decode(bytes, tag);
  if (decoded is! Map<String, Object?> || decoded['components'] == null) {
    throw StateError(
      'Downloaded spec for tag "$tag" does not look like an OpenAPI '
      'document: no top-level "components" object.',
    );
  }

  final String digest = sha256.convert(bytes).toString();

  File('tool/spec/spec3.sdk.json').writeAsBytesSync(bytes);
  File('tool/spec/SPEC_SHA256').writeAsStringSync('$digest\n');
  File('tool/spec/SPEC_VERSION').writeAsStringSync('$tag\n');

  stdout.writeln('Vendored tool/spec/spec3.sdk.json at $tag ($digest).');
}

String _parseTag(List<String> arguments) {
  for (int i = 0; i < arguments.length; i++) {
    final String argument = arguments[i];
    if (argument == '--tag') {
      if (i + 1 >= arguments.length) {
        throw ArgumentError('--tag requires a value, e.g. --tag v2111.');
      }
      return arguments[i + 1];
    }
    if (argument.startsWith('--tag=')) {
      return argument.substring('--tag='.length);
    }
  }
  throw ArgumentError(
    'Usage: dart run tool/spec/update_spec.dart --tag vNNNN\n'
    'Read the OPENAPI_VERSION file of the stripe-node release to track and '
    'pass its tag explicitly. This script never picks a tag on its own.',
  );
}

Object? _decode(List<int> bytes, String tag) {
  try {
    return json.decode(utf8.decode(bytes));
  } on FormatException catch (error) {
    throw FormatException(
      'Downloaded spec for tag "$tag" is not valid JSON: $error',
    );
  }
}
