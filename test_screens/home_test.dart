import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/features/catalog/application/catalog_providers.dart';
import 'package:kv_silver_mobile/features/catalog/data/catalog_repository.dart';
import 'package:kv_silver_mobile/features/home/presentation/home_screen.dart';
import 'fixtures.dart';
import 'screenshot.dart';

void main() {
  final overrides = [
    featuredProductsProvider.overrideWith((ref) async => sampleProducts),
    categoriesProvider.overrideWith((ref) async => sampleCategories),
    productsInCategoryProvider.overrideWith((ref, name) async => sampleProducts),
    silverRatesProvider.overrideWith((ref) async => sampleSilver),
    goldRatesProvider.overrideWith((ref) async => sampleGold),
    rateHistoryProvider.overrideWith((ref, key) async => key.$1 == Metal.silver ? sampleSilverHistory : const []),
  ];
  testWidgets('home', (t) => screenshot(t, 'home', const HomeScreen(), overrides: overrides));
  testWidgets('home scrolled', (t) => screenshot(t, 'home_scrolled', const HomeScreen(), overrides: overrides, scroll: 700));
}
