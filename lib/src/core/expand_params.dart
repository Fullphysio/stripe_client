/// Parameters accepted by a retrieve or list call that supports Stripe's
/// `expand` request parameter.
///
/// Every resource that lets a caller expand a nested field on the response
/// takes one of these as an optional trailing argument, so expansion is
/// requested the same way everywhere: `expand: ['data.latest_invoice']`.
final class ExpandParams {
  /// Creates the parameters, optionally requesting [expand] — a list of
  /// dotted field paths to expand in the response, such as
  /// `['customer', 'discounts']`.
  const ExpandParams({this.expand});

  /// The dotted field paths to expand in the response, when given.
  final List<String>? expand;

  /// Encodes these parameters the way every service using [ExpandParams]
  /// sends them.
  Map<String, Object?> toJson() => {
        if (expand != null) 'expand': expand,
      };
}
