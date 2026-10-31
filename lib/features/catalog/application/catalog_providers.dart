import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/pricing/pricing.dart';
import '../data/catalog_repository.dart';
import '../data/models/product.dart';

/// Today's silver rates, shared by every price on screen.
///
/// The web fetches these under two different query keys (`silver-rate-today`
/// and `silver-rates-today`), so the home widget refetches independently of the
/// product cards. One provider here avoids repeating that.
final silverRatesProvider = FutureProvider<List<MetalRate>>((ref) {
  return ref.watch(catalogRepositoryProvider).fetchSilverRates();
});

/// Today's gold rate. Empty when the metal has no rate for the day, in which
/// case the home rate strip hides the row.
final goldRatesProvider = FutureProvider<List<MetalRate>>((ref) {
  return ref.watch(catalogRepositoryProvider).fetchGoldRates();
});

/// Rate history for one metal over the last `days` days (marquee trend, rate page chart).
final rateHistoryProvider = FutureProvider.family<List<MetalRate>, (Metal, int)>((ref, key) {
  return ref.watch(catalogRepositoryProvider).fetchRateHistory(key.$1, key.$2);
});

final gstPercentProvider = FutureProvider<double>((ref) {
  return ref.watch(catalogRepositoryProvider).fetchGstPercent();
});

final categoriesProvider = FutureProvider<List<CategoryNode>>((ref) {
  return ref.watch(catalogRepositoryProvider).fetchCategories();
});

final tagsProvider = FutureProvider<List<String>>((ref) {
  return ref.watch(catalogRepositoryProvider).fetchTags();
});

/// Featured products for the home screen. The screen shows the first few.
final featuredProductsProvider = FutureProvider<List<Product>>((ref) {
  return ref.watch(catalogRepositoryProvider).fetchFeatured();
});

/// `/offers` "Discounted Pieces": newest products that are on sale or carry an
/// original price, first four (kv-ui Offers.tsx).
final discountedProductsProvider = FutureProvider<List<Product>>((ref) async {
  final all = await ref
      .watch(catalogRepositoryProvider)
      .fetchProducts(const ProductFilters(), page: 1, limit: 1000);
  return all.where((p) => p.isSale || (p.originalPrice ?? 0) != 0).take(4).toList();
});

/// Products in one category ("Related Products" on the product page).
final productsInCategoryProvider = FutureProvider.family<List<Product>, String>((ref, category) => ref
    .watch(catalogRepositoryProvider)
    .fetchProducts(ProductFilters(categories: [category]), page: 1, limit: 1000));

final productProvider = FutureProvider.family<Product, String>((ref, id) {
  return ref.watch(catalogRepositoryProvider).fetchProduct(id);
});

/// Rates arrive asynchronously; until they do, pricing falls back to the
/// listed price. Reading them as a plain list (empty while loading or failed)
/// mirrors the web's `= []` default and keeps the pricing call synchronous.
final silverRatesValueProvider = Provider<List<MetalRate>>((ref) {
  return ref.watch(silverRatesProvider).valueOrNull ?? const [];
});

class ProductListState {
  const ProductListState({
    this.items = const [],
    this.isLoadingFirstPage = true,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });

  final List<Product> items;
  final bool isLoadingFirstPage;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;

  ProductListState copyWith({
    List<Product>? items,
    bool? isLoadingFirstPage,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    bool clearError = false,
  }) =>
      ProductListState(
        items: items ?? this.items,
        isLoadingFirstPage: isLoadingFirstPage ?? this.isLoadingFirstPage,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        error: clearError ? null : (error ?? this.error),
      );
}

/// Page size, matching the web's `PAGE_SIZE = 12`.
const _pageSize = 12;

/// Paginated product list.
///
/// The server sends a **bare array with no total/count metadata**, so
/// end-of-list can only be inferred. Like the web, we stop on an empty page, a
/// short page, or a page *larger* than requested (which means the backend
/// ignored `limit` and returned everything), and we de-duplicate by id in case
/// `page` is ignored too.
class ProductListController extends StateNotifier<ProductListState> {
  ProductListController(this._repo) : super(const ProductListState());

  final CatalogRepository _repo;

  ProductFilters _filters = const ProductFilters();
  int _page = 1;
  int _requestId = 0;

  ProductFilters get filters => _filters;

  Future<void> applyFilters(ProductFilters filters) {
    _filters = filters;
    return refresh();
  }

  Future<void> refresh() async {
    _page = 1;
    final request = ++_requestId;
    state = const ProductListState(isLoadingFirstPage: true);

    try {
      final items = await _repo.fetchProducts(_filters, page: 1, limit: _pageSize);
      // A newer request superseded this one — drop the stale response so fast
      // typing cannot resurrect earlier results.
      if (request != _requestId) return;
      state = ProductListState(
        items: items,
        isLoadingFirstPage: false,
        hasMore: _looksLikeMore(items.length),
      );
    } catch (e) {
      if (request != _requestId) return;
      state = ProductListState(isLoadingFirstPage: false, hasMore: false, error: _message(e));
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.isLoadingFirstPage) return;
    final request = _requestId;
    state = state.copyWith(isLoadingMore: true, clearError: true);

    try {
      final next = await _repo.fetchProducts(_filters, page: _page + 1, limit: _pageSize);
      if (request != _requestId) return;

      final seen = state.items.map((p) => p.id).toSet();
      final fresh = next.where((p) => !seen.contains(p.id)).toList();

      // Every id already known means the backend ignored `page` — stop rather
      // than loop forever on the same rows.
      if (fresh.isEmpty) {
        state = state.copyWith(isLoadingMore: false, hasMore: false);
        return;
      }

      _page++;
      state = state.copyWith(
        items: [...state.items, ...fresh],
        isLoadingMore: false,
        hasMore: _looksLikeMore(next.length),
      );
    } catch (e) {
      if (request != _requestId) return;
      state = state.copyWith(isLoadingMore: false, error: _message(e));
    }
  }

  bool _looksLikeMore(int received) => received == _pageSize;

  String _message(Object e) => e.toString();
}

final productListProvider =
    StateNotifierProvider<ProductListController, ProductListState>((ref) {
  return ProductListController(ref.watch(catalogRepositoryProvider));
});
