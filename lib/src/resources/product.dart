import '../core/json_reading.dart';
import '../transport/stripe_client.dart';

/// A Stripe Product: the good or service a [Price] is attached to.
///
/// See https://stripe.com/docs/api/products/object.
final class Product {
  /// Creates a product directly from already-decoded fields.
  const Product({required this.id, this.name});

  /// Decodes [json] into a [Product].
  factory Product.fromJson(Map<String, Object?> json) => Product(
        id: json.requireString('id', 'Product'),
        name: json.optString('name'),
      );

  /// The product's unique identifier.
  final String id;

  /// The product's name, meant to be displayable to the customer.
  final String? name;

  @override
  String toString() => 'Product(id: $id, name: $name)';
}

/// Product operations: `client.products.retrieve(id)`.
final class ProductsService {
  /// Creates the service backed by [_client].
  ProductsService(this._client);

  final StripeClient _client;

  /// Retrieves the product with the given [id].
  Future<Product> retrieve(String id) async {
    final json = await _client.request(method: 'GET', path: '/v1/products/$id');
    return Product.fromJson(json as Map<String, Object?>);
  }
}
