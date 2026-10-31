import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/pricing/pricing.dart';
import 'models/product.dart';

/// The web's sort options. `featured` has no server order of its own — the web
/// sends `newest` for it (Shop.tsx), so it does too.
enum ProductSort { featured, newest, priceAsc, priceDesc }

extension ProductSortWire on ProductSort {
  /// Wire values the server accepts. Note the param is `sortBy`, not `sort`.
  String get wireValue => switch (this) {
        ProductSort.featured || ProductSort.newest => 'newest',
        ProductSort.priceAsc => 'price_asc',
        ProductSort.priceDesc => 'price_desc',
      };

  String get label => switch (this) {
        ProductSort.featured => 'Featured',
        ProductSort.newest => 'Newest',
        ProductSort.priceAsc => 'Price: Low to High',
        ProductSort.priceDesc => 'Price: High to Low',
      };
}

class ProductFilters {
  const ProductFilters({
    this.categories = const [],
    this.subcategories = const [],
    this.tags = const [],
    this.metals = const [],
    this.minPrice,
    this.maxPrice,
    this.search,
    this.sort = ProductSort.newest,
  });

  /// Matched against the product's `category` field server-side.
  final List<String> categories;
  final List<String> subcategories;
  final List<String> tags;

  /// Confusingly, `metal` filters on **purity**, not on a metal name.
  final List<String> metals;
  final double? minPrice;
  final double? maxPrice;
  final String? search;
  final ProductSort sort;

  bool get isEmpty =>
      categories.isEmpty &&
      subcategories.isEmpty &&
      tags.isEmpty &&
      metals.isEmpty &&
      minPrice == null &&
      maxPrice == null &&
      (search == null || search!.isEmpty);

  ProductFilters copyWith({
    List<String>? categories,
    List<String>? metals,
    double? minPrice,
    double? maxPrice,
    String? search,
    ProductSort? sort,
    bool clearPrice = false,
    bool clearSearch = false,
  }) =>
      ProductFilters(
        categories: categories ?? this.categories,
        subcategories: subcategories,
        tags: tags,
        metals: metals ?? this.metals,
        minPrice: clearPrice ? null : (minPrice ?? this.minPrice),
        maxPrice: clearPrice ? null : (maxPrice ?? this.maxPrice),
        search: clearSearch ? null : (search ?? this.search),
        sort: sort ?? this.sort,
      );

  /// Multi-select values are comma-joined into a single param, as on web.
  Map<String, dynamic> toQuery({required int page, required int limit}) => {
        if (categories.isNotEmpty) 'category': categories.join(','),
        if (subcategories.isNotEmpty) 'subcategory': subcategories.join(','),
        if (tags.isNotEmpty) 'tags': tags.join(','),
        if (metals.isNotEmpty) 'metal': metals.join(','),
        if (minPrice != null) 'minPrice': minPrice,
        if (maxPrice != null) 'maxPrice': maxPrice,
        if (search != null && search!.isNotEmpty) 'search': search,
        'sortBy': sort.wireValue,
        'page': page,
        'limit': limit,
      };
}

/// Catalogue reads. Every endpoint here decodes differently — `/products` and
/// `/silver-rates/today` are bare arrays, `/products/:id` is a bare object, and
/// `/products/categories` and `/pricing-config` use a `{status, data}` envelope.
/// There is no consistent wrapper to factor out.
enum Metal {
  silver('silver-rates'),
  gold('gold-rates');

  const Metal(this.path);
  final String path;
}

/// A top-level category and its subcategories (kv-ui `CategoryNode`).
class CategoryNode {
  const CategoryNode(this.name, [this.subcategories = const []]);

  /// Tolerates the old flat string list too.
  factory CategoryNode.fromJson(dynamic e) => e is Map
      ? CategoryNode(
          (e['name'] ?? '').toString(),
          [for (final s in (e['subcategories'] as List? ?? const [])) s.toString()],
        )
      : CategoryNode(e.toString());

  final String name;
  final List<String> subcategories;
}

class CatalogRepository {
  CatalogRepository(this._api);

  final ApiClient _api;

  Future<List<Product>> fetchProducts(
    ProductFilters filters, {
    required int page,
    required int limit,
  }) async {
    final data = await _api.get('/products', query: filters.toQuery(page: page, limit: limit));
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => Product.fromJson(e.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<Product> fetchProduct(String id) async {
    final data = await _api.get('/products/$id');
    return Product.fromJson((data as Map).cast<String, dynamic>());
  }

  /// Curated products for the home screen, from the dedicated
  /// `/products/featured` route — a bare array, like `/products`. This is a
  /// different endpoint from `/products?featured=true`; the web uses this one.
  Future<List<Product>> fetchFeatured() async {
    final data = await _api.get('/products/featured');
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => Product.fromJson(e.cast<String, dynamic>()))
        .toList(growable: false);
  }

  /// `{status, data: [{name, subcategories}]}` — a two-level tree.
  Future<List<CategoryNode>> fetchCategories() async {
    final data = await _api.get('/products/categories');
    final list = data is Map ? data['data'] : data;
    if (list is! List) return const [];
    return list.map(CategoryNode.fromJson).toList(growable: false);
  }

  /// Tags in use across active products, `{status, data: [String]}`.
  Future<List<String>> fetchTags() async {
    final data = await _api.get('/products/tags');
    final list = data is Map ? data['data'] : data;
    if (list is! List) return const [];
    return list.map((e) => e.toString()).toList(growable: false);
  }

  /// Silver rates drive product pricing. The response is a bare array whose
  /// elements key the day as `rateDate` (gold sends both `date` and `rateDate`,
  /// silver only `rateDate`), and the id as `id` rather than `_id`.
  Future<List<MetalRate>> fetchSilverRates() async =>
      _parseRates(await _api.get('/silver-rates/today'));

  /// Today's gold rate. Same bare-array shape as silver.
  Future<List<MetalRate>> fetchGoldRates() async =>
      _parseRates(await _api.get('/gold-rates/today'));

  /// `GET /{silver|gold}-rates/history?days=n`, same shape as today's rates.
  Future<List<MetalRate>> fetchRateHistory(Metal metal, int days) async =>
      _parseRates(await _api.get('/${metal.path}/history', query: {'days': days}));

  List<MetalRate> _parseRates(dynamic data) {
    if (data is! List) return const [];
    return data.whereType<Map>().map((raw) {
      final e = raw.cast<String, dynamic>();
      return MetalRate(
        id: (e['id'] ?? e['_id'] ?? '').toString(),
        date: (e['rateDate'] ?? e['date'] ?? e['createdAt'] ?? '').toString(),
        ratePerGram: _toDouble(e['ratePerGram']) ?? 0,
        ratePerKg: _toDouble(e['ratePerKg']) ?? 0,
        purity: (e['purity'] ?? '').toString(),
        updatedBy: e['updatedBy'] as String?,
      );
    }).toList(growable: false);
  }

  /// Returns the GST percent (3 means 3%). Defaults to the server's own default
  /// rather than throwing, matching the web, so a config outage never blocks a
  /// price from rendering.
  Future<double> fetchGstPercent() async {
    try {
      final data = await _api.get('/pricing-config');
      final payload = data is Map ? data['data'] : null;
      if (payload is Map) {
        return _toDouble(payload['gstPercent']) ?? 3;
      }
    } catch (_) {
      // Fall through to the default.
    }
    return 3;
  }

  static double? _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepository(ref.watch(apiClientProvider));
});
