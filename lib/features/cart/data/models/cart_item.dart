import '../../../catalog/data/models/product.dart';

/// A cart line.
///
/// The **client is authoritative** for the cart, not the server. `kv-api`'s
/// cart stores only `{productId, quantity}` and re-derives weight and price
/// from the base product, so it cannot represent "same product, 30 g variant"
/// — the selected variant would be silently lost on every sync. We therefore
/// keep the full line locally (and in shared preferences) and treat the server
/// cart as a coarse cross-device backup.
///
/// [unitPrice] is the pre-GST price that was on screen when the item was added.
/// It is display-only: the server re-prices authoritatively at checkout.
class CartItem {
  const CartItem({
    required this.productId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
    required this.inStock,
    required this.stockAvailable,
    this.variantWeight,
    this.variantLabel,
    this.imageData,
  });

  final String productId;
  final String name;
  final double unitPrice;
  final int quantity;
  final bool inStock;
  final int stockAvailable;

  /// Free-text weight of the selected variant, e.g. `"30 g"`. Sent to the
  /// server as `variantWeight` so it prices the same weight the customer saw.
  final String? variantWeight;

  /// Kept for display only — the server never persists a variant label.
  final String? variantLabel;

  /// Base64 or URL, copied from the product so the cart renders offline.
  final String? imageData;

  double get lineTotal => unitPrice * quantity;

  /// Identity includes the variant: the same product in two sizes is two lines.
  String get lineKey => '$productId::${variantWeight ?? ''}';

  CartItem copyWith({int? quantity, bool? inStock, int? stockAvailable, double? unitPrice}) =>
      CartItem(
        productId: productId,
        name: name,
        unitPrice: unitPrice ?? this.unitPrice,
        quantity: quantity ?? this.quantity,
        inStock: inStock ?? this.inStock,
        stockAvailable: stockAvailable ?? this.stockAvailable,
        variantWeight: variantWeight,
        variantLabel: variantLabel,
        imageData: imageData,
      );

  factory CartItem.fromProduct(
    Product product, {
    required double unitPrice,
    required int quantity,
    ProductVariant? variant,
  }) =>
      CartItem(
        productId: product.id,
        name: product.name,
        unitPrice: unitPrice,
        quantity: quantity,
        inStock: product.inStock,
        stockAvailable: product.stockAvailable,
        variantWeight: variant?.weight.isNotEmpty == true
            ? variant!.weight
            : (product.weightInGrams > 0 ? '${product.weightInGrams} g' : null),
        variantLabel: variant?.label,
        imageData: product.primaryImage?.data,
      );

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'name': name,
        'unitPrice': unitPrice,
        'quantity': quantity,
        'inStock': inStock,
        'stockAvailable': stockAvailable,
        if (variantWeight != null) 'variantWeight': variantWeight,
        if (variantLabel != null) 'variantLabel': variantLabel,
        if (imageData != null) 'imageData': imageData,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        productId: (json['productId'] ?? '').toString(),
        name: (json['name'] ?? '') as String,
        unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        inStock: json['inStock'] != false,
        stockAvailable: (json['stockAvailable'] as num?)?.toInt() ?? 0,
        variantWeight: json['variantWeight'] as String?,
        variantLabel: json['variantLabel'] as String?,
        imageData: json['imageData'] as String?,
      );

  /// Line shape accepted by `/payments/create-order` and `POST /orders`.
  /// `product` is the id key those endpoints expect (not `productId`), and
  /// `variantWeight` is the only channel through which a variant reaches the
  /// server's pricing.
  Map<String, dynamic> toOrderLine() => {
        'product': productId,
        'quantity': quantity,
        if (variantWeight != null) 'variantWeight': variantWeight,
      };
}
