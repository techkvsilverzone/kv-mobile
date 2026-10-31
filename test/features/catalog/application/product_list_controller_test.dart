import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/core/pricing/pricing.dart';
import 'package:kv_silver_mobile/features/catalog/application/catalog_providers.dart';
import 'package:kv_silver_mobile/features/catalog/data/catalog_repository.dart';
import 'package:kv_silver_mobile/features/catalog/data/models/product.dart';

Product _product(String id) => Product.fromJson({
      '_id': id,
      'name': 'Product $id',
      'weight': 10,
      'price': 100,
      'listedPrice': 100,
      'isFixedPrice': true,
      'inStock': true,
      'stockAvailable': 1,
    });

class FakeCatalogRepository implements CatalogRepository {
  FakeCatalogRepository(this.pages);

  /// Keyed by requested page number.
  final Map<int, List<Product>> pages;
  final List<int> requestedPages = [];
  Object? error;

  @override
  Future<List<Product>> fetchProducts(ProductFilters filters,
      {required int page, required int limit}) async {
    requestedPages.add(page);
    if (error != null) throw error!;
    return pages[page] ?? const [];
  }

  @override
  Future<Product> fetchProduct(String id) async => _product(id);

  @override
  Future<List<Product>> fetchFeatured() async => const [];

  @override
  Future<List<CategoryNode>> fetchCategories() async => const [];

  @override
  Future<List<String>> fetchTags() async => const [];

  @override
  Future<List<MetalRate>> fetchGoldRates() async => const [];

  @override
  Future<List<MetalRate>> fetchSilverRates() async => const [];

  @override
  Future<double> fetchGstPercent() async => 3;

  @override
  Future<List<MetalRate>> fetchRateHistory(Metal metal, int days) async => const [];
}

/// A full page, so the controller believes more may follow.
List<Product> fullPage(int start) =>
    List.generate(12, (i) => _product('p${start + i}'));

void main() {
  test('refresh loads the first page', () async {
    final repo = FakeCatalogRepository({1: fullPage(0)});
    final controller = ProductListController(repo);

    await controller.refresh();

    expect(controller.state.items.length, 12);
    expect(controller.state.isLoadingFirstPage, isFalse);
    expect(controller.state.hasMore, isTrue);
  });

  test('a short page means the end of the list', () async {
    final repo = FakeCatalogRepository({1: [_product('a'), _product('b')]});
    final controller = ProductListController(repo);

    await controller.refresh();

    // No total/count metadata exists, so a short page is the only end signal.
    expect(controller.state.hasMore, isFalse);
  });

  test('loadMore appends the next page', () async {
    final repo = FakeCatalogRepository({1: fullPage(0), 2: fullPage(100)});
    final controller = ProductListController(repo);
    await controller.refresh();

    await controller.loadMore();

    expect(controller.state.items.length, 24);
    expect(repo.requestedPages, [1, 2]);
  });

  test('stops when the backend ignores `page` and returns the same rows', () async {
    // Same ids on page 2 — without the de-dupe guard this would loop forever.
    final repo = FakeCatalogRepository({1: fullPage(0), 2: fullPage(0)});
    final controller = ProductListController(repo);
    await controller.refresh();

    await controller.loadMore();

    expect(controller.state.items.length, 12);
    expect(controller.state.hasMore, isFalse);
  });

  test('does not request more once the end is known', () async {
    final repo = FakeCatalogRepository({1: [_product('a')]});
    final controller = ProductListController(repo);
    await controller.refresh();

    await controller.loadMore();

    expect(repo.requestedPages, [1]);
  });

  test('a failed first page surfaces an error and stops paging', () async {
    final repo = FakeCatalogRepository({})..error = Exception('boom');
    final controller = ProductListController(repo);

    await controller.refresh();

    expect(controller.state.error, isNotNull);
    expect(controller.state.items, isEmpty);
    expect(controller.state.hasMore, isFalse);
  });

  test('a failed later page keeps the rows already loaded', () async {
    final repo = FakeCatalogRepository({1: fullPage(0)});
    final controller = ProductListController(repo);
    await controller.refresh();
    repo.error = Exception('boom');

    await controller.loadMore();

    expect(controller.state.items.length, 12);
    expect(controller.state.error, isNotNull);
    expect(controller.state.isLoadingMore, isFalse);
  });

  test('applying filters resets paging back to page 1', () async {
    final repo = FakeCatalogRepository({1: fullPage(0), 2: fullPage(100)});
    final controller = ProductListController(repo);
    await controller.refresh();
    await controller.loadMore();

    await controller.applyFilters(const ProductFilters(search: 'anklet'));

    expect(repo.requestedPages, [1, 2, 1]);
    expect(controller.state.items.length, 12);
  });
}
