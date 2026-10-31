import '../../../../core/config/env.dart';
import '../../../../core/pricing/pricing.dart';

/// A size/weight option. Variants have **no `_id`** server-side (`{_id: false}`),
/// so they are identified by index or [label], never by id.
class ProductVariant {
  const ProductVariant({required this.label, required this.weight, this.height, this.breadth});

  final String label;

  /// Free text, e.g. `"20 g"` or `"12.5"` — unlike [Product.weight], which is
  /// numeric. Run it through [parseGrams] before doing arithmetic.
  final String weight;
  final String? height;
  final String? breadth;

  String get displayLabel => label.isNotEmpty ? label : weight;

  static ProductVariant? tryFromJson(Map<String, dynamic> json) {
    final label = (json['label'] ?? '').toString().trim();
    final weight = (json['weight'] ?? '').toString().trim();
    // The web drops entries lacking both; mirror that so empty chips don't render.
    if (label.isEmpty && weight.isEmpty) return null;
    return ProductVariant(
      label: label,
      weight: weight,
      height: _trimOrNull(json['height']),
      breadth: _trimOrNull(json['breadth']),
    );
  }

  static String? _trimOrNull(dynamic v) {
    final s = v?.toString().trim() ?? '';
    return s.isEmpty ? null : s;
  }
}

/// Product images are **not URLs**. Each entry is
/// `{variantName, imageBase64, sortOrder}`, where `imageBase64` holds either a
/// base64 data URI or a plain URL string — callers must handle both.
/// `https://host/api/v1` → `https://host`.
String resolveApiOrigin(String apiBaseUrl) {
  final u = Uri.tryParse(apiBaseUrl);
  return u == null || u.host.isEmpty ? '' : u.replace(path: '', query: null, fragment: null).toString().replaceAll(RegExp(r'/$'), '');
}

class ProductImage {
  const ProductImage({required this.data, required this.sortOrder, this.variantName});

  final String data;
  final int sortOrder;
  final String? variantName;

  /// A URL to load: absolute, or a server path ("/images/products/…") resolved
  /// against the API's origin (as the web's `normalizeImageSrc` does).
  bool get isRemote => data.startsWith('http://') || data.startsWith('https://') || data.startsWith('/');

  /// [data] as a loadable URL when [isRemote].
  String get url => data.startsWith('/') ? '${resolveApiOrigin(Env.apiBaseUrl)}$data' : data;

  static ProductImage? tryFromJson(dynamic raw) {
    if (raw is String) {
      return raw.trim().isEmpty ? null : ProductImage(data: raw.trim(), sortOrder: 0);
    }
    if (raw is! Map) return null;
    final data = (raw['imageBase64'] ?? raw['url'] ?? '').toString().trim();
    if (data.isEmpty) return null;
    return ProductImage(
      data: data,
      sortOrder: (raw['sortOrder'] as num?)?.toInt() ?? 0,
      variantName: raw['variantName'] as String?,
    );
  }
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.listedPrice,
    required this.isFixedPrice,
    required this.weightInGrams,
    required this.images,
    required this.variants,
    required this.inStock,
    required this.stockAvailable,
    this.description,
    this.material,
    this.purity,
    this.originalPrice,
    this.isSale = false,
    this.isNew = false,
    this.makingCharge,
    this.wastage,
    this.makingCharges,
    this.makingChargePercent,
    this.makingChargePerGram,
    this.serverRatePerGram,
    this.serverPurityFraction,
  });

  /// `_id` — products expose no `id` alias, unlike addresses and metal rates.
  final String id;
  final String name;
  final String? description;

  /// The category field is called `material` on the wire; there is no
  /// `category` key in the response (only as a *query parameter*).
  final String? material;

  /// **Server-computed live unit price**, pre-GST — not the stored price.
  /// We still recompute client-side for display, because selecting a variant
  /// changes the weight and the server's figure assumes the default one.
  final double price;

  /// The raw stored price. Used as the fallback when a live rate is missing.
  final double listedPrice;
  final double? originalPrice;
  final bool isSale;
  final bool isNew;

  final bool isFixedPrice;

  /// Numeric grams. The wire sends `weight` as a **number**, and repeats it as
  /// `weightInGrams`; neither is the `"12.5 g"` string the spec implied.
  final double weightInGrams;

  final String? purity;

  /// Both can arrive as explicit JSON `null` (not merely absent) — the server
  /// writes null for fixed-price products.
  final ProductCharge? makingCharge;
  final ProductCharge? wastage;

  /// Legacy making-charge fields (null = not set) and the rate/purity the server
  /// priced with — inputs to the server-identical price in [toPricingInput].
  final double? makingCharges;
  final double? makingChargePercent;
  final double? makingChargePerGram;
  final double? serverRatePerGram;
  final double? serverPurityFraction;

  final List<ProductImage> images;
  final List<ProductVariant> variants;
  final bool inStock;
  final int stockAvailable;

  ProductImage? get primaryImage => images.isEmpty ? null : images.first;

  factory Product.fromJson(Map<String, dynamic> json) {
    final images = (json['images'] as List?)
            ?.map(ProductImage.tryFromJson)
            .whereType<ProductImage>()
            .toList() ??
        <ProductImage>[];
    // Lowest sortOrder is the primary image.
    images.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final variants = (json['variants'] as List?)
            ?.whereType<Map>()
            .map((v) => ProductVariant.tryFromJson(v.cast<String, dynamic>()))
            .whereType<ProductVariant>()
            .toList() ??
        <ProductVariant>[];

    final weight = _toDouble(json['weightInGrams']) ?? _toDouble(json['weight']) ?? 0;
    final listed = _toDouble(json['listedPrice']) ?? _toDouble(json['price']) ?? 0;

    return Product(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '') as String,
      description: json['description'] as String?,
      material: json['material'] as String?,
      price: _toDouble(json['price']) ?? listed,
      listedPrice: listed,
      originalPrice: _toDouble(json['originalPrice']),
      isSale: json['isSale'] == true,
      isNew: (json['isNewItem'] ?? json['isNew']) == true,
      isFixedPrice: json['isFixedPrice'] == true,
      weightInGrams: weight,
      purity: json['purity']?.toString(),
      makingCharge: _chargeFromJson(json['makingCharge']),
      wastage: _chargeFromJson(json['wastage']),
      makingCharges: _toDouble(json['makingCharges']),
      makingChargePercent: _toDouble(json['makingChargePercent']),
      makingChargePerGram: _toDouble(json['makingChargePerGram']),
      serverRatePerGram: json['pricing'] is Map ? _toDouble((json['pricing'] as Map)['ratePerGram']) : null,
      serverPurityFraction: json['pricing'] is Map ? _toDouble((json['pricing'] as Map)['purityFraction']) : null,
      images: images,
      variants: variants,
      stockAvailable: (json['stockAvailable'] as num?)?.toInt() ?? 0,
      // Fall back to the stock number when the flag is absent.
      inStock: json['inStock'] == true ||
          (json['inStock'] == null && ((json['stockAvailable'] as num?)?.toInt() ?? 0) > 0),
    );
  }

  /// Adapts this product to the ported pricing engine's input shape.
  ProductPricingInput toPricingInput() => ProductPricingInput(
        price: listedPrice,
        isFixedPrice: isFixedPrice,
        weightInGrams: weightInGrams > 0 ? weightInGrams : null,
        purity: purity,
        material: material,
        makingCharge: makingCharge,
        wastage: wastage,
        makingCharges: makingCharges,
        makingChargePercent: makingChargePercent,
        makingChargePerGram: makingChargePerGram,
        serverRatePerGram: serverRatePerGram,
        serverPurityFraction: serverPurityFraction,
      );

  static double? _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static ProductCharge? _chargeFromJson(dynamic raw) {
    if (raw is! Map) return null;
    final value = _toDouble(raw['value']);
    if (value == null) return null;
    // Enum literals are lowercase 'percentage' | 'amount'; anything else
    // defaults to percentage, matching the server's own write path.
    final type = (raw['type'] ?? '').toString() == 'amount'
        ? ChargeType.amount
        : ChargeType.percentage;
    return ProductCharge(type: type, value: value);
  }
}
