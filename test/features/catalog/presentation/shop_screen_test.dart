import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
    expect(find.text('No matching pieces'), findsOneWidget);
    expect(find.text('0 products'), findsOneWidget);
    expect(find.text('Filters · 1'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'anklet');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(repo.seen.last.categories, isEmpty);
    expect(repo.seen.last.search, 'anklet');
  });
  testWidgets('?focus=search focuses the search field', (tester) async {
    final container = ProviderContainer(
        overrides: [catalogRepositoryProvider.overrideWithValue(_RecordingRepo())]);
    addTearDown(container.dispose);
    final router = GoRouter(initialLocation: '/shop?focus=search', routes: [
      GoRoute(path: '/shop', builder: (_, __) => const ShopScreen()),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus, isTrue);
  });

  testWidgets('filter sheet applies on Apply and clears the search', (tester) async {
    final repo = _RecordingRepo();
    final container = ProviderContainer(overrides: [catalogRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ShopScreen(initialSearch: 'ring')),
    ));
    await tester.pumpAndSettle();
    expect(repo.seen.last.search, 'ring');

    final before = repo.seen.length;
    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Jewellery'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Rings'));
    await tester.pumpAndSettle();
    expect(repo.seen.length, before, reason: 'nothing is fetched until Apply');
    await tester.tap(find.text('Apply · 2'));
    await tester.pumpAndSettle();
    expect(repo.seen.last.categories, ['Jewellery']);
    expect(repo.seen.last.subcategories, ['Rings']);
    expect(repo.seen.last.search, isNull);
  });
}
