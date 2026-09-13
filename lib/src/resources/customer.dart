import '../core/expand_params.dart';
import '../core/json_reading.dart';
import '../transport/stripe_client.dart';

/// A Stripe Customer.
///
/// See https://stripe.com/docs/api/customers/object.
final class Customer {
  /// Creates a customer directly from already-decoded fields.
  const Customer({
    required this.id,
    this.email,
    this.name,
    this.metadata = const {},
    this.balance,
    this.currency,
    this.deleted,
  });

  /// Decodes [json] into a [Customer].
  factory Customer.fromJson(Map<String, Object?> json) => Customer(
        id: json.requireString('id', 'Customer'),
        email: json.optString('email'),
        name: json.optString('name'),
        metadata: json.optStringMap('metadata'),
        balance: json.optInt('balance'),
        currency: json.optString('currency'),
        deleted: json.optBool('deleted'),
      );

  /// The customer's unique identifier.
  final String id;

  /// The customer's email address, when Stripe has one on file.
  final String? email;

  /// The customer's full name or business name, when Stripe has one on
  /// file.
  final String? name;

  /// A set of key-value pairs Stripe attaches to the customer.
  final Map<String, String> metadata;

  /// The customer's current balance, in cents (or local equivalent). A
  /// negative value means Stripe owes the customer money, applied to their
  /// next invoice; a positive value means the customer owes Stripe money,
  /// added to their next invoice.
  final int? balance;

  /// Three-letter ISO currency code, in lowercase, that [balance] is
  /// denominated in, when Stripe has recorded a currency for it.
  final String? currency;

  /// Whether this customer has been deleted, when Stripe's response
  /// carries that flag (a "deleted customer" shape).
  final bool? deleted;

  @override
  String toString() => 'Customer(id: $id, email: $email, name: $name)';
}

/// Parameters for updating a Customer.
///
/// See https://stripe.com/docs/api/customers/update.
final class CustomerUpdateParams {
  /// Creates parameters updating whichever of [email], [name], and
  /// [metadata] are given; every field is optional, and an omitted field is
  /// left unchanged on the customer.
  const CustomerUpdateParams({this.email, this.name, this.metadata});

  /// The new email address, when changing it.
  final String? email;

  /// The new full name or business name, when changing it.
  final String? name;

  /// The new set of key-value pairs to attach to the customer, when
  /// changing it. Replaces the existing metadata entirely.
  final Map<String, String>? metadata;

  /// Encodes these parameters the way [CustomersService.update] sends them.
  Map<String, Object?> toJson() => {
        if (email != null) 'email': email,
        if (name != null) 'name': name,
        if (metadata != null) 'metadata': metadata,
      };

  @override
  String toString() => 'CustomerUpdateParams(email: $email, name: $name)';
}

/// Parameters for creating a customer balance transaction.
///
/// See https://stripe.com/docs/api/customer_balance_transactions/create.
final class CustomerCreateBalanceTransactionParams {
  /// Creates parameters adjusting a customer's balance by [amount], in
  /// [currency].
  ///
  /// A positive [amount] increases the amount the customer owes Stripe on
  /// their next invoice; a negative [amount] decreases it (a credit).
  const CustomerCreateBalanceTransactionParams({
    required this.amount,
    required this.currency,
    this.description,
    this.metadata,
  });

  /// The amount, in cents (or local equivalent), to adjust the customer's
  /// balance by. A negative value credits the customer's balance.
  final int amount;

  /// Three-letter ISO currency code, in lowercase.
  final String currency;

  /// An arbitrary string attached to this transaction, meant to be
  /// displayable to the customer.
  final String? description;

  /// A set of key-value pairs to attach to this transaction.
  final Map<String, String>? metadata;

  /// Encodes these parameters the way
  /// [CustomersService.createBalanceTransaction] sends them.
  Map<String, Object?> toJson() => {
        'amount': amount,
        'currency': currency,
        if (description != null) 'description': description,
        if (metadata != null) 'metadata': metadata,
      };

  @override
  String toString() => 'CustomerCreateBalanceTransactionParams('
      'amount: $amount, currency: $currency)';
}

/// A Stripe Customer Balance Transaction: one adjustment to a customer's
/// account balance.
///
/// See https://stripe.com/docs/api/customer_balance_transactions/object.
final class CustomerBalanceTransaction {
  /// Creates a balance transaction directly from already-decoded fields.
  const CustomerBalanceTransaction({
    required this.id,
    this.amount,
    this.currency,
    this.description,
    this.endingBalance,
    this.created,
  });

  /// Decodes [json] into a [CustomerBalanceTransaction].
  factory CustomerBalanceTransaction.fromJson(Map<String, Object?> json) =>
      CustomerBalanceTransaction(
        id: json.requireString('id', 'CustomerBalanceTransaction'),
        amount: json.optInt('amount'),
        currency: json.optString('currency'),
        description: json.optString('description'),
        endingBalance: json.optInt('ending_balance'),
        created: json.optUnixTime('created'),
      );

  /// The transaction's unique identifier.
  final String id;

  /// The amount, in cents (or local equivalent), of this transaction. A
  /// negative value represents a credit to the customer's balance.
  final int? amount;

  /// Three-letter ISO currency code, in lowercase.
  final String? currency;

  /// An arbitrary string attached to this transaction, meant to be
  /// displayable to the customer.
  final String? description;

  /// The customer's balance after this transaction was applied, in cents
  /// (or local equivalent).
  final int? endingBalance;

  /// When this transaction was created.
  final DateTime? created;

  @override
  String toString() => 'CustomerBalanceTransaction(id: $id, '
      'amount: $amount, endingBalance: $endingBalance)';
}

/// Customer operations: `client.customers.retrieve(id)`,
/// `client.customers.update(id, ...)`,
/// `client.customers.createBalanceTransaction(id, ...)`.
final class CustomersService {
  /// Creates the service backed by [_client].
  CustomersService(this._client);

  final StripeClient _client;

  /// Retrieves the customer with the given [id].
  Future<Customer> retrieve(String id, [ExpandParams? params]) async {
    final json = await _client.request(
      method: 'GET',
      path: '/v1/customers/$id',
      params: params?.toJson(),
    );
    return Customer.fromJson(json as Map<String, Object?>);
  }

  /// Updates the customer with the given [id].
  ///
  /// [idempotencyKey] overrides the automatically generated key that makes
  /// retries of this call safe; see [StripeClient.request].
  Future<Customer> update(
    String id,
    CustomerUpdateParams params, {
    String? idempotencyKey,
  }) async {
    final json = await _client.request(
      method: 'POST',
      path: '/v1/customers/$id',
      params: params.toJson(),
      idempotencyKey: idempotencyKey,
    );
    return Customer.fromJson(json as Map<String, Object?>);
  }

  /// Creates a balance transaction for the customer with the given
  /// [customerId].
  ///
  /// [idempotencyKey] overrides the automatically generated key that makes
  /// retries of this call safe; see [StripeClient.request].
  Future<CustomerBalanceTransaction> createBalanceTransaction(
    String customerId,
    CustomerCreateBalanceTransactionParams params, {
    String? idempotencyKey,
  }) async {
    final json = await _client.request(
      method: 'POST',
      path: '/v1/customers/$customerId/balance_transactions',
      params: params.toJson(),
      idempotencyKey: idempotencyKey,
    );
    return CustomerBalanceTransaction.fromJson(json as Map<String, Object?>);
  }
}
