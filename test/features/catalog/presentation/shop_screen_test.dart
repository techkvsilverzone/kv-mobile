import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/features/catalog/data/catalog_repository.dart';
import 'package:kv_silver_mobile/features/catalog/data/models/product.dart';
import 'package:kv_silver_mobile/features/catalog/presentation/shop_screen.dart';
import '../application/product_list_controller_test.dart' show FakeCatalogRepository;

class _RecordingRepo extends FakeCatalogRepository {
  _RecordingRepo() : super(const {});
  final List<ProductFilters> seen = [];

  @override
  Future<List<CategoryNode>> fetchCategories() async =>
      const [CategoryNode('Coins'), CategoryNode('Jewellery', ['Rings'])];

  @override
  Future<List<Product>> fetchProducts(ProductFilters filters,
      {required int page, required int limit}) async {
    seen.add(filters);
    return const [];
  }
}

void main() {
  test('preset price buckets map to bounds like the web', () {
    expect(priceBounds(''), (null, null));
    expect(priceBounds('500-1000'), (500.0, 1000.0));
    expect(priceBounds('5000+'), (5000.0, null));
  });

  testWidgets('?category= pre-filters, typing a search clears filters', (tester) async {
    final repo = _RecordingRepo();
    final container = ProviderContainer(
        overrides: [catalogRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ShopScreen(initialCategory: 'Coins')),
    ));
    await tester.pumpAndSettle();

    expect(repo.seen.last.categories, ['Coins']);
    expect(find.text('No products found matching your criteria.'), findsOneWidget);
    expect(find.text('Showing 0 products'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'anklet');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(repo.seen.last.categories, isEmpty);
    expect(repo.seen.last.search, 'anklet');
  });
}
