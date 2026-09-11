/// The intermediate representation shared by the generator's stages.
///
/// The pipeline is `spec -> resolve -> classify -> IR -> emit`. This file is
/// the contract between the classifier and the emitters, so every stage can
/// be built and tested against hand-written IR without waiting on the others.
///
/// Nothing here knows about JSON Schema, and nothing here emits Dart source.
library;

import 'package:meta/meta.dart';

/// A Dart type a generated field can have.
///
/// Deliberately closed: the classifier must map every schema shape Stripe
/// uses onto one of these, and a shape it cannot map is a generation failure,
/// not a silent fallback to `Object?`.
@immutable
sealed class IrType {
  const IrType();
}

/// One of Dart's built-in scalar types.
@immutable
final class IrPrimitive extends IrType {
  /// Creates a primitive of the given [kind].
  const IrPrimitive(this.kind);

  /// Which scalar this is.
  final IrPrimitiveKind kind;
}

/// The scalar types a Stripe field can hold.
enum IrPrimitiveKind {
  /// A JSON string.
  string,

  /// A JSON integer. Monetary amounts are integers in the minor currency
  /// unit and use this, not [double].
  integer,

  /// A JSON number that is not an integer.
  double,

  /// A JSON boolean.
  boolean,
}

/// An integer field carrying `format: unix-time`, surfaced as a UTC
/// [DateTime] so call sites never hand-roll the `* 1000` conversion.
@immutable
final class IrDateTime extends IrType {
  /// Creates the unix-time type.
  const IrDateTime();
}

/// A `format: decimal` string, kept as a [String].
///
/// Stripe sends these as strings precisely because a [double] cannot hold
/// their precision; converting would lose data.
@immutable
final class IrDecimalString extends IrType {
  /// Creates the decimal-string type.
  const IrDecimalString();
}

/// A free-form `metadata` map.
@immutable
final class IrMetadataMap extends IrType {
  /// Creates the metadata-map type.
  const IrMetadataMap();
}

/// A reference to another generated class.
@immutable
final class IrRef extends IrType {
  /// Creates a reference to [className].
  const IrRef(this.className);

  /// The generated Dart class name.
  final String className;
}

/// A reference to a generated open-enum class.
@immutable
final class IrEnumRef extends IrType {
  /// Creates a reference to [enumName].
  const IrEnumRef(this.enumName);

  /// The generated Dart enum-class name.
  final String enumName;
}

/// A plain JSON array.
@immutable
final class IrList extends IrType {
  /// Creates a list of [element].
  const IrList(this.element);

  /// The element type.
  final IrType element;
}

/// Stripe's list envelope: `{object: "list", data: [...], has_more, url}`.
///
/// Distinct from [IrList] because it decodes through `StripeList<T>` rather
/// than a bare Dart [List].
@immutable
final class IrStripeList extends IrType {
  /// Creates a Stripe list of [element].
  const IrStripeList(this.element);

  /// The element type.
  final IrType element;
}

/// A field that is either a bare object id or the full object, depending on
/// whether the request expanded it.
///
/// Detected from the spec's `x-expansionResources` marker, never guessed from
/// the shape of an `anyOf`.
@immutable
final class IrExpandable extends IrType {
  /// Creates an expandable pointing at [target].
  const IrExpandable(this.target);

  /// What the expanded value decodes to: an [IrRef], an [IrUnion] when the
  /// marker lists several resources, or [IrStub] when the target was pruned.
  final IrType target;
}

/// A closed union of generated classes discriminated at decode time.
///
/// Stripe uses this for live-or-tombstone pairs such as `Customer` and
/// `DeletedCustomer`, which share an `object` value and are told apart by the
/// presence of `deleted: true`.
@immutable
final class IrUnion extends IrType {
  /// Creates a union named [unionName] over [variants].
  const IrUnion(this.unionName, this.variants, this.discriminator);

  /// The generated sealed supertype's name.
  final String unionName;

  /// The concrete classes, in declaration order.
  final List<IrRef> variants;

  /// How the variants are told apart.
  final IrUnionDiscriminator discriminator;
}

/// How an [IrUnion]'s variants are distinguished in a decoded payload.
enum IrUnionDiscriminator {
  /// The variant carrying `deleted: true` is the tombstone; the other is live.
  deletedFlag,
}

/// A reference the allowlist pruned.
///
/// Decodes to `StripeStub`, which keeps the id, the `object` value and the raw
/// JSON, so a pruned field stays identifiable and loggable instead of being
/// dropped. Widening the allowlist turns this back into an [IrRef].
@immutable
final class IrStub extends IrType {
  /// Creates the stub type, recording which schema was pruned and why.
  const IrStub(this.prunedSchema, this.reason);

  /// The schema key that would have been generated.
  final String prunedSchema;

  /// Why the allowlist prunes it, copied from the allowlist entry.
  final String reason;
}

/// An escape hatch for a shape with no better Dart representation, decoded as
/// `Map<String, Object?>`.
///
/// The classifier must justify every use; a spec bump that starts producing
/// these in quantity is a signal the classifier needs extending.
@immutable
final class IrRaw extends IrType {
  /// Creates the raw type.
  const IrRaw();
}

/// What a [ClassIr] is for.
enum ClassIrKind {
  /// A response object decoded from the API. Every field is nullable and read
  /// tolerantly.
  model,

  /// A request-parameter object. Absent fields are omitted from the wire
  /// rather than sent as explicit null.
  params,
}

/// One generated Dart class.
@immutable
final class ClassIr {
  /// Creates a class IR node.
  const ClassIr({
    required this.schemaKey,
    required this.className,
    required this.fileName,
    required this.kind,
    required this.fields,
    this.docs,
    this.objectLiteral,
  });

  /// The raw spec key, such as `checkout.session`. Kept for traceability and
  /// for the semantic changelog emitted on a spec bump.
  final String schemaKey;

  /// The generated Dart class name, such as `CheckoutSession`.
  final String className;

  /// The file this class is emitted into, relative to its output directory.
  final String fileName;

  /// Whether this is a response model or a request-parameter object.
  final ClassIrKind kind;

  /// The fields, in spec order.
  final List<FieldIr> fields;

  /// Dartdoc lifted from the schema's `description`.
  final String? docs;

  /// The constant value of the `object` discriminator, when the schema has
  /// one. Kept for wire fidelity and logging, never used for branching.
  final String? objectLiteral;
}

/// One field of a [ClassIr].
@immutable
final class FieldIr {
  /// Creates a field IR node.
  const FieldIr({
    required this.wireName,
    required this.dartName,
    required this.type,
    required this.nullable,
    required this.requiredInSpec,
    required this.nullableInSpec,
    this.docs,
    this.defaultsToEmpty = false,
  });

  /// The JSON key, such as `current_period_start`.
  final String wireName;

  /// The Dart field name, such as `currentPeriodStart`.
  final String dartName;

  /// The field's type.
  final IrType type;

  /// Whether the Dart type is nullable.
  ///
  /// For [ClassIrKind.model] this is true for everything except `id` and
  /// `object`, regardless of what the spec says. Stripe's `required` means
  /// "the key is present", not "the value is non-null" — `coupon.amount_off`
  /// is marked both — and it says nothing about other API versions omitting
  /// the key. Trusting it is what breaks decoding in production.
  final bool nullable;

  /// Whether the spec listed this field as required. Drives dartdoc only.
  final bool requiredInSpec;

  /// Whether the spec marked this field nullable. Drives dartdoc only.
  final bool nullableInSpec;

  /// Dartdoc lifted from the property's `description`.
  final String? docs;

  /// Whether an absent value decodes to an empty collection rather than null.
  ///
  /// Set for lists and metadata maps, where collapsing "absent" into "empty"
  /// loses nothing and saves every call site a null check.
  final bool defaultsToEmpty;
}

/// One generated open-enum class.
///
/// Emitted as a class rather than a Dart `enum`: a native enum cannot carry a
/// value Stripe adds after generation without discarding the wire string, and
/// its compile-time exhaustiveness would turn every spec bump into a break in
/// unrelated call sites.
@immutable
final class EnumIr {
  /// Creates an enum IR node.
  const EnumIr({
    required this.enumName,
    required this.fileName,
    required this.values,
    this.docs,
  });

  /// The generated Dart class name.
  final String enumName;

  /// The file this enum is emitted into.
  final String fileName;

  /// The values known at generation time, in spec order.
  final List<EnumValueIr> values;

  /// Dartdoc lifted from the schema's `description`.
  final String? docs;
}

/// One value of an [EnumIr].
@immutable
final class EnumValueIr {
  /// Creates an enum value.
  const EnumValueIr({
    required this.wire,
    required this.dartName,
    this.docs,
  });

  /// The raw string as sent on the wire, such as `incomplete_expired`.
  final String wire;

  /// The Dart constant name, such as `incompleteExpired`.
  final String dartName;

  /// Dartdoc for this value, when the spec documents it.
  final String? docs;
}

/// One method on a generated service class, from `x-stripeOperations`.
@immutable
final class OperationIr {
  /// Creates an operation IR node.
  const OperationIr({
    required this.methodName,
    required this.httpMethod,
    required this.path,
    required this.pathParameters,
    required this.kind,
    this.paramsClassName,
    this.returnType,
    this.docs,
  });

  /// The Dart method name, such as `retrieve`.
  final String methodName;

  /// The HTTP verb, uppercase.
  final String httpMethod;

  /// The path template, such as `/v1/subscriptions/{subscription_exposed_id}`.
  ///
  /// Stripe is inconsistent about placeholder names even within one resource,
  /// so these are substituted positionally by [pathParameters] order rather
  /// than matched by name.
  final String path;

  /// The placeholder names in [path], in order of appearance.
  final List<String> pathParameters;

  /// Which request shape this operation uses.
  final OperationKind kind;

  /// The generated request-params class, when the operation takes a body or
  /// query parameters.
  final String? paramsClassName;

  /// What the response decodes to.
  final IrType? returnType;

  /// Dartdoc lifted from the operation's `description`.
  final String? docs;
}

/// Which response shape and pagination semantics an operation has.
enum OperationKind {
  /// Returns a single object.
  object,

  /// Returns a list page paginated by `starting_after` / `ending_before`.
  list,

  /// Returns a search page paginated by the opaque `next_page` token.
  search,
}

/// One generated service class, grouping the operations of a resource.
@immutable
final class ServiceIr {
  /// Creates a service IR node.
  const ServiceIr({
    required this.className,
    required this.fileName,
    required this.operations,
    this.namespace,
    this.docs,
  });

  /// The generated Dart class name, such as `SubscriptionsService`.
  final String className;

  /// The file this service is emitted into.
  final String fileName;

  /// The operations, in spec order.
  final List<OperationIr> operations;

  /// The namespace segment this service hangs off, such as `checkout` for
  /// `stripe.checkout.sessions`. Null for a top-level resource.
  final String? namespace;

  /// Dartdoc lifted from the resource's `description`.
  final String? docs;
}

/// Everything the emitters need, and the whole output of the classifier.
@immutable
final class GeneratorIr {
  /// Creates the top-level IR.
  const GeneratorIr({
    required this.models,
    required this.params,
    required this.enums,
    required this.services,
    required this.unions,
    required this.prunedSchemas,
  });

  /// Response model classes.
  final List<ClassIr> models;

  /// Request-parameter classes.
  final List<ClassIr> params;

  /// Open-enum classes.
  final List<EnumIr> enums;

  /// Service classes.
  final List<ServiceIr> services;

  /// Sealed union supertypes, such as `CustomerOrDeleted`.
  final List<IrUnion> unions;

  /// Schema keys the allowlist pruned, mapped to the reason. Emitted into the
  /// semantic changelog so a reviewer can see what is deliberately missing.
  final Map<String, String> prunedSchemas;
}
