import '../core/expand_params.dart';
import '../core/expandable.dart';
import '../core/json_reading.dart';
import '../core/stripe_list.dart';
import '../transport/stripe_client.dart';
import 'discount.dart';

/// A single line item on an [Invoice].
///
/// See https://stripe.com/docs/api/invoice-line-item/object.
final class InvoiceLineItem {
  /// Creates a line item directly from already-decoded fields.
  const InvoiceLineItem({
    required this.id,
    this.amount,
    this.currency,
    this.quantity,
    this.description,
  });

  /// Decodes [json] into an [InvoiceLineItem].
  factory InvoiceLineItem.fromJson(Map<String, Object?> json) =>
      InvoiceLineItem(
        id: json.requireString('id', 'InvoiceLineItem'),
        amount: json.optInt('amount'),
        currency: json.optString('currency'),
        quantity: json.optInt('quantity'),
        description: json.optString('description'),
      );

  /// The line item's unique identifier.
  final String id;

  /// The amount, in cents (or local equivalent), of this line item.
  final int? amount;

  /// Three-letter ISO currency code, in lowercase.
  final String? currency;

  /// The quantity of the line item's price or plan, when it has one.
  final int? quantity;

  /// A description of this line item, meant to be displayable to the
  /// customer.
  final String? description;

  @override
  String toString() =>
      'InvoiceLineItem(id: $id, amount: $amount, description: $description)';
}

/// The aggregate tax amount for one tax rate applied across an [Invoice]'s
/// line items.
///
/// See https://stripe.com/docs/api/invoices/object#invoice_object-total_tax_amounts.
final class InvoiceTaxAmount {
  /// Creates a tax amount directly from already-decoded fields.
  const InvoiceTaxAmount({this.amount, this.inclusive});

  /// Decodes [json] into an [InvoiceTaxAmount].
  factory InvoiceTaxAmount.fromJson(Map<String, Object?> json) =>
      InvoiceTaxAmount(
        amount: json.optInt('amount'),
        inclusive: json.optBool('inclusive'),
      );

  /// The amount, in cents (or local equivalent), of tax this rate
  /// contributed.
  final int? amount;

  /// Whether this tax amount is inclusive in the line items' prices, rather
  /// than added on top of them.
  final bool? inclusive;

  @override
  String toString() =>
      'InvoiceTaxAmount(amount: $amount, inclusive: $inclusive)';
}

/// Identifies the tax rate behind one [InvoiceTotalTax] entry, when Stripe
/// attributes the tax to a specific tax rate rather than another mechanism.
///
/// See https://stripe.com/docs/api/invoices/object#invoice_object-total_taxes.
final class InvoiceTotalTaxRateDetails {
  /// Creates tax rate details directly from an already-decoded [taxRate] id.
  const InvoiceTotalTaxRateDetails({this.taxRate});

  /// Decodes [json] into [InvoiceTotalTaxRateDetails].
  factory InvoiceTotalTaxRateDetails.fromJson(Map<String, Object?> json) =>
      InvoiceTotalTaxRateDetails(taxRate: json.optString('tax_rate'));

  /// The id of the tax rate this tax amount was calculated from.
  final String? taxRate;

  @override
  String toString() => 'InvoiceTotalTaxRateDetails(taxRate: $taxRate)';
}

/// One entry of an [Invoice]'s `total_taxes` array — the tax reporting
/// shape used by accounts on the API version this package pins
/// (`2025-11-17.clover`), replacing the older [InvoiceTaxAmount] shape.
///
/// See https://stripe.com/docs/api/invoices/object#invoice_object-total_taxes.
final class InvoiceTotalTax {
  /// Creates a total tax entry directly from already-decoded fields.
  const InvoiceTotalTax({
    this.amount,
    this.taxBehavior,
    this.taxabilityReason,
    this.taxableAmount,
    this.taxRateDetails,
  });

  /// Decodes [json] into an [InvoiceTotalTax].
  factory InvoiceTotalTax.fromJson(Map<String, Object?> json) =>
      InvoiceTotalTax(
        amount: json.optInt('amount'),
        taxBehavior: json.optString('tax_behavior'),
        taxabilityReason: json.optString('taxability_reason'),
        taxableAmount: json.optInt('taxable_amount'),
        taxRateDetails: json.optNested(
          'tax_rate_details',
          InvoiceTotalTaxRateDetails.fromJson,
        ),
      );

  /// The amount, in cents (or local equivalent), of this tax.
  final int? amount;

  /// Whether this tax is `'inclusive'` or `'exclusive'` of the line items'
  /// prices.
  final String? taxBehavior;

  /// The reasoning behind this tax, for example `'product_exempt'`.
  final String? taxabilityReason;

  /// The amount, in cents (or local equivalent), on which this tax was
  /// calculated.
  final int? taxableAmount;

  /// The tax rate this amount was calculated from, when Stripe attributes
  /// it to one.
  final InvoiceTotalTaxRateDetails? taxRateDetails;

  @override
  String toString() =>
      'InvoiceTotalTax(amount: $amount, taxBehavior: $taxBehavior)';
}

/// The aggregate discount amount for one discount applied across an
/// [Invoice]'s line items.
///
/// See https://stripe.com/docs/api/invoices/object#invoice_object-total_discount_amounts.
final class InvoiceDiscountAmount {
  /// Creates a discount amount directly from already-decoded fields.
  const InvoiceDiscountAmount({this.amount, this.discount});

  /// Decodes [json] into an [InvoiceDiscountAmount].
  factory InvoiceDiscountAmount.fromJson(Map<String, Object?> json) =>
      InvoiceDiscountAmount(
        amount: json.optInt('amount'),
        discount: switch (json['discount']) {
          null => null,
          final discountJson => Expandable<Discount>.fromJson(
              discountJson,
              Discount.fromJson,
              (discount) => discount.id,
              fieldName: 'invoice.total_discount_amounts.discount',
            ),
        },
      );

  /// The amount, in cents (or local equivalent), of this discount.
  final int? amount;

  /// The discount this amount is attributed to — either a bare id, or the
  /// expanded [Discount] when the request expanded it.
  final Expandable<Discount>? discount;

  @override
  String toString() => 'InvoiceDiscountAmount(amount: $amount)';
}

/// A Stripe Invoice.
///
/// See https://stripe.com/docs/api/invoices/object.
final class Invoice {
  /// Creates an invoice directly from already-decoded fields.
  const Invoice({
    required this.id,
    this.hostedInvoiceUrl,
    this.status,
    this.amountPaid,
    this.subtotal,
    this.total,
    this.currency,
    this.discounts = const [],
    this.lines,
    this.totalTaxes = const [],
    this.totalTaxAmounts = const [],
    this.totalDiscountAmounts = const [],
  });

  /// Decodes [json] into an [Invoice].
  factory Invoice.fromJson(Map<String, Object?> json) => Invoice(
        id: json.requireString('id', 'Invoice'),
        hostedInvoiceUrl: json.optString('hosted_invoice_url'),
        status: json.optString('status'),
        amountPaid: json.optInt('amount_paid'),
        subtotal: json.optInt('subtotal'),
        total: json.optInt('total'),
        currency: json.optString('currency'),
        discounts: json.optList<Expandable<Discount>>(
          'discounts',
          (element) => Expandable<Discount>.fromJson(
            element,
            Discount.fromJson,
            (discount) => discount.id,
            fieldName: 'invoice.discounts[]',
          ),
        ),
        lines: json.optNested(
          'lines',
          (linesJson) => StripeList<InvoiceLineItem>.fromJson(
              linesJson, InvoiceLineItem.fromJson),
        ),
        totalTaxes: json.optList<InvoiceTotalTax>(
          'total_taxes',
          (element) =>
              InvoiceTotalTax.fromJson(element as Map<String, Object?>),
        ),
        totalTaxAmounts: json.optList<InvoiceTaxAmount>(
          'total_tax_amounts',
          (element) =>
              InvoiceTaxAmount.fromJson(element as Map<String, Object?>),
        ),
        totalDiscountAmounts: json.optList<InvoiceDiscountAmount>(
          'total_discount_amounts',
          (element) =>
              InvoiceDiscountAmount.fromJson(element as Map<String, Object?>),
        ),
      );

  /// The invoice's unique identifier.
  final String id;

  /// The URL for the hosted invoice page, which allows customers to view
  /// and pay an invoice, when Stripe generated one.
  final String? hostedInvoiceUrl;

  /// The status of this invoice: `'draft'`, `'open'`, `'paid'`, `'uncollectible'`,
  /// or `'void'`.
  final String? status;

  /// The total amount, in cents (or local equivalent), that was paid on
  /// this invoice.
  final int? amountPaid;

  /// The subtotal, in cents (or local equivalent), before discount and
  /// tax.
  final int? subtotal;

  /// The total amount, in cents (or local equivalent), after discount and
  /// tax.
  final int? total;

  /// Three-letter ISO currency code, in lowercase.
  final String? currency;

  /// The discounts applied to this invoice — each either a bare id, or the
  /// expanded [Discount] when the request expanded `discounts`.
  final List<Expandable<Discount>> discounts;

  /// The individual line items that make up this invoice.
  final StripeList<InvoiceLineItem>? lines;

  /// The aggregate tax information of all line items, decoded from
  /// `total_taxes` — the shape sent by accounts on this package's pinned
  /// API version (`2025-11-17.clover`) or later. Prefer [totalTaxAmount]
  /// over reading this list directly.
  final List<InvoiceTotalTax> totalTaxes;

  /// The aggregate tax amounts, one per tax rate, calculated across every
  /// line item, decoded from the legacy `total_tax_amounts` field. Stripe
  /// replaced this shape with `total_taxes` ([totalTaxes]) in later API
  /// versions; this is kept for accounts still pinned to an older one.
  /// Prefer [totalTaxAmount] over reading this list directly.
  final List<InvoiceTaxAmount> totalTaxAmounts;

  /// The aggregate discount amounts, one per discount, calculated across
  /// every line item.
  final List<InvoiceDiscountAmount> totalDiscountAmounts;

  /// This invoice's total tax, in cents (or local equivalent), summed from
  /// whichever of the two tax shapes Stripe populated.
  ///
  /// Stripe reshaped invoice tax reporting between API versions: accounts
  /// on `2025-11-17.clover` (this package's pinned version) or later send
  /// `total_taxes` ([totalTaxes]), a richer per-tax-rate breakdown; accounts
  /// still pinned to an older API version instead send the legacy
  /// `total_tax_amounts` shape ([totalTaxAmounts]). The two are never both
  /// populated for the same invoice. Read this getter rather than either
  /// list directly — code that only sums [totalTaxAmounts] silently reports
  /// zero tax for an account that has moved to the newer API version, which
  /// is exactly the class of bug this package exists to avoid.
  ///
  /// Returns `null`, not `0`, when neither field is populated — meaning tax
  /// was not calculated on this invoice at all, which is distinct from a
  /// genuinely zero-tax invoice (which returns `0`).
  int? get totalTaxAmount {
    if (totalTaxes.isNotEmpty) {
      return totalTaxes.fold<int>(0, (sum, tax) => sum + (tax.amount ?? 0));
    }
    if (totalTaxAmounts.isNotEmpty) {
      return totalTaxAmounts.fold<int>(
          0, (sum, tax) => sum + (tax.amount ?? 0));
    }
    return null;
  }

  @override
  String toString() =>
      'Invoice(id: $id, status: $status, total: $total, currency: $currency)';
}

/// Invoice operations: `client.invoices.retrieve(id)`.
final class InvoicesService {
  /// Creates the service backed by [_client].
  InvoicesService(this._client);

  final StripeClient _client;

  /// Retrieves the invoice with the given [id].
  ///
  /// Pass `expand: ['discounts']` in [params] to read `promotion_code` off
  /// each of the invoice's discounts.
  Future<Invoice> retrieve(String id, [ExpandParams? params]) async {
    final json = await _client.request(
      method: 'GET',
      path: '/v1/invoices/$id',
      params: params?.toJson(),
    );
    return Invoice.fromJson(json as Map<String, Object?>);
  }
}
