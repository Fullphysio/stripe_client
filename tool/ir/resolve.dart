import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:yaml/yaml.dart';

/// One rule excluding a schema from the resolved closure, with the reason it
/// was excluded so widening the allowlist later is a one-line change instead
/// of a rediscovery.
class PruneRule {
  /// Creates a prune rule for the schema key [id], with [reason] documenting
  /// which field pulled it in and why it is out of scope.
  const PruneRule({required this.id, required this.reason});

  /// The `components.schemas` key excluded from the resolved closure.
  final String id;

  /// Why [id] is excluded.
  final String reason;
}

/// The generator's allowlist: which schemas seed the closure walk, which
/// payment-method types survive the PaymentMethod-shaped fan-out trim, and
/// which schemas are pruned on sight.
class Allowlist {
  /// Creates an allowlist directly. Prefer [Allowlist.load] to read one from
  /// the vendored YAML file, or [Allowlist.parse] to parse YAML already held
  /// in memory (as tests do).
  Allowlist({
    required this.specTag,
    required this.specFile,
    required this.resources,
    required this.paymentMethodTypes,
    required this.prune,
  }) : pruneReasonById = <String, String>{
          for (final PruneRule rule in prune) rule.id: rule.reason,
        };

  /// The `stripe/openapi` tag this allowlist was written against.
  final String specTag;

  /// Path to the spec file within the tagged release, e.g.
  /// `openapi/spec3.sdk.json`.
  final String specFile;

  /// Seed schema keys the closure walk starts from. Each must be an exact
  /// `components.schemas` key — not a resource name, class name, or guess.
  final List<String> resources;

  /// Payment-method type slugs (e.g. `card`, `link`) to keep wherever a
  /// schema fans out into one property per payment-method type. A type not
  /// in this set is pruned at every such fan-out point, wherever it occurs.
  final Set<String> paymentMethodTypes;

  /// Schemas excluded from the closure regardless of how they are reached.
  final List<PruneRule> prune;

  /// [prune] indexed by [PruneRule.id] for O(1) lookup during the walk.
  final Map<String, String> pruneReasonById;

  /// Parses an [Allowlist] from a YAML document already held in memory.
  factory Allowlist.parse(String yamlSource) {
    final Object? document = loadYaml(yamlSource);
    if (document is! Map) {
      throw FormatException(
        'Allowlist YAML must be a mapping at the top level, got '
        '${document.runtimeType}.',
      );
    }

    final Object? specNode = document['spec'];
    if (specNode is! Map) {
      throw const FormatException(
        'Allowlist is missing a "spec" mapping with "tag" and "file".',
      );
    }
    final String specTag = _requireString(specNode, 'tag', context: 'spec');
    final String specFile = _requireString(specNode, 'file', context: 'spec');

    final List<String> resources = _requireStringList(document, 'resources');
    if (resources.isEmpty) {
      throw const FormatException('Allowlist "resources" must not be empty.');
    }

    final List<String> paymentMethodTypes = _requireStringList(
      document,
      'paymentMethodTypes',
    );

    final Object? pruneNode = document['prune'] ?? const <Object?>[];
    if (pruneNode is! List) {
      throw FormatException(
        'Allowlist "prune" must be a list, got ${pruneNode.runtimeType}.',
      );
    }
    final List<PruneRule> prune = <PruneRule>[
      for (final Object? entry in pruneNode) _parsePruneRule(entry),
    ];

    return Allowlist(
      specTag: specTag,
      specFile: specFile,
      resources: resources,
      paymentMethodTypes: paymentMethodTypes.toSet(),
      prune: prune,
    );
  }

  /// Reads and parses an [Allowlist] from the YAML file at [path].
  factory Allowlist.load(String path) =>
      Allowlist.parse(File(path).readAsStringSync());

  static PruneRule _parsePruneRule(Object? entry) {
    if (entry is! Map) {
      throw FormatException(
        'Each "prune" entry must be a mapping with "id" and "reason", got '
        '$entry.',
      );
    }
    final String id = _requireString(entry, 'id', context: 'prune entry');
    final String reason = _requireString(
      entry,
      'reason',
      context: 'prune entry "$id"',
    );
    return PruneRule(id: id, reason: reason);
  }

  static String _requireString(
    Map<Object?, Object?> map,
    String key, {
    required String context,
  }) {
    final Object? value = map[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('$context is missing a non-empty "$key" string.');
    }
    return value;
  }

  static List<String> _requireStringList(
      Map<Object?, Object?> map, String key) {
    final Object? value = map[key];
    if (value is! List) {
      throw FormatException(
        'Allowlist "$key" must be a list, got ${value.runtimeType}.',
      );
    }
    return <String>[
      for (final Object? entry in value)
        if (entry is String)
          entry
        else
          throw FormatException(
            'Allowlist "$key" entries must be strings, got $entry.',
          ),
    ];
  }
}

/// A schema deliberately excluded from [ResolvedSchemas.schemas], and every
/// place in the resolved graph whose field pointed at it — so the emitter
/// can still type that field (e.g. as `Expandable<StripeStub>`) instead of
/// silently dropping it.
class PrunedReference {
  /// Creates an empty pruned-reference record for [schemaId]; call sites are
  /// added afterwards through [referencedFrom].
  PrunedReference({required this.schemaId, required this.reason});

  /// The `components.schemas` key that was excluded.
  final String schemaId;

  /// Why [schemaId] was excluded: either a matching [PruneRule.reason], or a
  /// generated explanation naming the payment-method type that was trimmed.
  final String reason;

  /// Dotted breadcrumbs (e.g. `"charge.on_behalf_of"`) of every field in the
  /// resolved graph that referenced [schemaId].
  final Set<String> referencedFrom = <String>{};
}

/// The resolved, pruned set of schemas to generate, plus metadata about
/// every schema that was excluded rather than followed.
class ResolvedSchemas {
  /// Creates a result pairing resolved [schemas] with [prunedReferences].
  const ResolvedSchemas(
      {required this.schemas, required this.prunedReferences});

  /// Resolved schemas to generate, keyed by `components.schemas` name.
  final Map<String, Map<String, Object?>> schemas;

  /// Schemas excluded from generation, keyed by schema name.
  ///
  /// Pruning is decided per referencing field, not per target, so a schema
  /// id can appear here even when it is also a key in [schemas]: one field's
  /// edge to it was excluded (e.g. a disallowed payment-method type) while a
  /// different field elsewhere still legitimately pulls the same schema in.
  final Map<String, PrunedReference> prunedReferences;
}

/// Resolves [allowlist]'s seed resources to their transitive `$ref` closure
/// within [spec], applying the payment-method-type trim and the prune list.
///
/// Every entry in [Allowlist.resources] must be an exact `components.schemas`
/// key; an unresolvable seed throws [StateError] naming it. A `$ref` whose
/// target does not exist in [spec] also throws [StateError] — exclusion is
/// only ever the deliberate result of [Allowlist.prune] or the
/// payment-method-type trim, never a silent skip of a broken reference.
ResolvedSchemas resolveSchemas({
  required Map<String, Object?> spec,
  required Allowlist allowlist,
}) {
  final Object? components = spec['components'];
  if (components is! Map<String, Object?>) {
    throw const FormatException('Spec is missing a "components" object.');
  }
  final Object? schemasNode = components['schemas'];
  if (schemasNode is! Map<String, Object?>) {
    throw const FormatException('Spec is missing "components.schemas".');
  }

  for (final String seed in allowlist.resources) {
    if (!schemasNode.containsKey(seed)) {
      throw StateError(
        'Unresolvable seed "$seed": no schema with this key exists in '
        'components.schemas. Seeds must be exact schema keys (for example '
        '"checkout.session", not "checkout_session").',
      );
    }
  }
  final Set<String> paymentMethodTypeUniverse = _paymentMethodTypeUniverse(
    schemasNode,
  );
  for (final String type in allowlist.paymentMethodTypes) {
    if (!paymentMethodTypeUniverse.contains(type)) {
      throw StateError(
        'Allowlist "paymentMethodTypes" entry "$type" is not a value of '
        'payment_method.properties.type.enum in this spec.',
      );
    }
  }

  final _Resolver resolver = _Resolver(
    schemas: schemasNode,
    allowlist: allowlist,
    paymentMethodTypeUniverse: paymentMethodTypeUniverse,
  );
  return resolver.run(allowlist.resources);
}

/// Reads the vendored OpenAPI spec at [specPath] and verifies its SHA-256
/// digest against the hex digest recorded at [shaPath], throwing if they do
/// not match. Guards generation against silently running on a corrupted or
/// stale vendored file.
Map<String, Object?> loadVerifiedSpec({
  required String specPath,
  required String shaPath,
}) {
  final List<int> bytes = File(specPath).readAsBytesSync();
  final String actualSha256 = sha256.convert(bytes).toString();
  final String expectedSha256 = File(shaPath).readAsStringSync().trim();
  if (actualSha256 != expectedSha256) {
    throw StateError(
      'Vendored spec at "$specPath" does not match "$shaPath": expected '
      'sha256 $expectedSha256 but computed $actualSha256. Re-run '
      'tool/spec/update_spec.dart or restore the vendored file.',
    );
  }
  final Object? decoded = json.decode(utf8.decode(bytes));
  if (decoded is! Map<String, Object?>) {
    throw FormatException(
        'Spec at "$specPath" did not decode to a JSON object.');
  }
  return decoded;
}

Set<String> _paymentMethodTypeUniverse(Map<String, Object?> schemas) {
  if (!schemas.containsKey('payment_method')) {
    return const <String>{};
  }
  final Object? paymentMethod = schemas['payment_method'];
  if (paymentMethod is! Map<String, Object?>) {
    throw StateError(
      '"payment_method" is not a JSON object; cannot derive the '
      'payment-method-type universe used to trim its fan-out.',
    );
  }
  final Object? properties = paymentMethod['properties'];
  if (properties is! Map<String, Object?>) {
    throw StateError(
      '"payment_method" schema has no "properties"; cannot derive the '
      'payment-method-type universe.',
    );
  }
  final Object? typeProperty = properties['type'];
  if (typeProperty is! Map<String, Object?>) {
    throw StateError(
      '"payment_method.properties.type" is missing; cannot derive the '
      'payment-method-type universe.',
    );
  }
  final Object? enumValues = typeProperty['enum'];
  if (enumValues is! List<Object?> || enumValues.isEmpty) {
    throw StateError(
      '"payment_method.properties.type.enum" is missing or empty; cannot '
      'derive the payment-method-type universe.',
    );
  }
  return <String>{for (final Object? value in enumValues) value as String};
}

class _Resolver {
  _Resolver({
    required this.schemas,
    required this.allowlist,
    required this.paymentMethodTypeUniverse,
  });

  final Map<String, Object?> schemas;
  final Allowlist allowlist;
  final Set<String> paymentMethodTypeUniverse;

  final Set<String> _visited = <String>{};
  final Map<String, Map<String, Object?>> _resolved =
      <String, Map<String, Object?>>{};
  final Map<String, PrunedReference> _prunedReferences =
      <String, PrunedReference>{};
  final Queue<String> _queue = Queue<String>();

  ResolvedSchemas run(List<String> seeds) {
    for (final String seed in seeds) {
      if (_visited.add(seed)) {
        _queue.add(seed);
      }
    }
    while (_queue.isNotEmpty) {
      final String current = _queue.removeFirst();
      final Object? definition = schemas[current];
      if (definition is! Map<String, Object?>) {
        throw StateError('Schema "$current" is not a JSON object in the spec.');
      }
      _resolved[current] = definition;
      _walk(definition, current);
    }
    return ResolvedSchemas(
      schemas: Map<String, Map<String, Object?>>.unmodifiable(_resolved),
      prunedReferences:
          Map<String, PrunedReference>.unmodifiable(_prunedReferences),
    );
  }

  void _walk(Object? node, String path) {
    if (node is Map<String, Object?>) {
      final Object? ref = node[r'$ref'];
      if (ref is String) {
        _considerEdge(target: _refTarget(ref, path), path: path);
        return;
      }
      final Object? properties = node['properties'];
      if (properties is Map<String, Object?>) {
        for (final MapEntry<String, Object?> entry in properties.entries) {
          _walk(entry.value, '$path.${entry.key}');
        }
      }
      for (final String key in const <String>['allOf', 'anyOf', 'oneOf']) {
        final Object? composed = node[key];
        if (composed is List<Object?>) {
          for (final Object? item in composed) {
            _walk(item, path);
          }
        }
      }
      final Object? items = node['items'];
      if (items != null) {
        _walk(items, path);
      }
      final Object? additionalProperties = node['additionalProperties'];
      if (additionalProperties is Map<String, Object?>) {
        _walk(additionalProperties, path);
      }
    } else if (node is List<Object?>) {
      for (final Object? item in node) {
        _walk(item, path);
      }
    }
  }

  String _refTarget(String ref, String path) {
    const String prefix = '#/components/schemas/';
    if (!ref.startsWith(prefix)) {
      throw FormatException(
        'Unsupported \$ref "$ref" at "$path": expected a local '
        'components/schemas reference.',
      );
    }
    return ref.substring(prefix.length);
  }

  void _considerEdge({required String target, required String path}) {
    if (!schemas.containsKey(target)) {
      throw StateError(
        'Broken \$ref: "$path" points at schema "$target", which does not '
        'exist in components.schemas.',
      );
    }

    final String? globalReason = allowlist.pruneReasonById[target];
    if (globalReason != null) {
      _recordPrune(id: target, reason: globalReason, path: path);
      return;
    }

    final String propertyName = path.split('.').last;
    if (paymentMethodTypeUniverse.contains(propertyName) &&
        !allowlist.paymentMethodTypes.contains(propertyName)) {
      _recordPrune(
        id: target,
        reason: 'Payment-method type "$propertyName" is not in '
            'allowlist.paymentMethodTypes.',
        path: path,
      );
      return;
    }

    if (_visited.add(target)) {
      _queue.add(target);
    }
  }

  void _recordPrune({
    required String id,
    required String reason,
    required String path,
  }) {
    final PrunedReference reference = _prunedReferences.putIfAbsent(
      id,
      () => PrunedReference(schemaId: id, reason: reason),
    );
    reference.referencedFrom.add(path);
  }
}
