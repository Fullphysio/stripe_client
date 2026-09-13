import '../core/json_reading.dart';

/// The payload carried by a Stripe [Event]: the object the event is about,
/// as raw, undecoded JSON.
///
/// Deeply typing every possible event payload — one shape per [Event.type],
/// of which Stripe has well over a hundred — is out of scope for this
/// package. Callers narrow [object] themselves once they have branched on
/// [Event.type], typically by passing it to the `fromJson` of whichever
/// resource that event type carries.
///
/// See https://stripe.com/docs/api/events/object#event_object-data.
final class EventData {
  /// Creates event data directly from an already-decoded [object].
  const EventData({required this.object});

  /// Decodes [json] into an [EventData].
  factory EventData.fromJson(Map<String, Object?> json) =>
      EventData(object: json.optObject('object') ?? const {});

  /// The raw, undecoded object this event is about.
  final Map<String, Object?> object;

  @override
  String toString() => 'EventData(object: $object)';
}

/// A Stripe Event: a notification that something changed on the account,
/// the payload of a webhook delivery.
///
/// There is no service for this resource — events reach this package
/// exclusively through `StripeWebhooks.constructEvent`, never fetched
/// directly.
///
/// See https://stripe.com/docs/api/events/object.
final class Event {
  /// Creates an event directly from already-decoded fields.
  const Event({
    required this.id,
    this.type,
    this.apiVersion,
    this.created,
    this.data,
    this.livemode,
  });

  /// Decodes [json] into an [Event].
  factory Event.fromJson(Map<String, Object?> json) => Event(
        id: json.requireString('id', 'Event'),
        type: json.optString('type'),
        apiVersion: json.optString('api_version'),
        created: json.optUnixTime('created'),
        data: json.optNested('data', EventData.fromJson),
        livemode: json.optBool('livemode'),
      );

  /// The event's unique identifier.
  final String id;

  /// The event's type, for example `'invoice.paid'` or
  /// `'customer.subscription.deleted'`.
  final String? type;

  /// The Stripe API version used to render [data], when Stripe sent one.
  final String? apiVersion;

  /// When this event was created.
  final DateTime? created;

  /// The object this event is about.
  final EventData? data;

  /// Whether this event occurred in live mode, rather than test mode.
  final bool? livemode;

  @override
  String toString() => 'Event(id: $id, type: $type)';
}
