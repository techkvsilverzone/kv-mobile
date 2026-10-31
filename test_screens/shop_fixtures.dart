// Extra fixtures for the shop & product screenshots.
import 'dart:async';
import 'package:kv_silver_mobile/core/pricing/pricing.dart';
import 'package:kv_silver_mobile/features/catalog/data/catalog_repository.dart';
import 'package:kv_silver_mobile/features/catalog/data/models/product.dart';
import 'package:kv_silver_mobile/features/reviews/reviews.dart';
import 'fixtures.dart';

class ScreenCatalogRepo implements CatalogRepository {
  ScreenCatalogRepo({this.products = const [], this.hang = false});
  final List<Product> products;
  final bool hang;

  @override
  Future<List<Product>> fetchProducts(ProductFilters filters, {required int page, required int limit}) =>
      hang ? Completer<List<Product>>().future : Future.value(page == 1 ? products : const []);
  @override
  Future<Product> fetchProduct(String id) async => sampleProducts.firstWhere((p) => p.id == id);
  @override
  Future<List<Product>> fetchFeatured() async => sampleProducts;
  @override
  Future<List<CategoryNode>> fetchCategories() async => [
        ...sampleCategories.take(3),
        const CategoryNode('Bangles', ['Kids', 'Kada']),
        ...sampleCategories.skip(4),
      ];
  @override
  Future<List<String>> fetchTags() async => const ['Bridal', 'Daily wear', 'Gifting', 'Temple'];
  @override
  Future<List<MetalRate>> fetchSilverRates() async => sampleSilver;
  @override
  Future<List<MetalRate>> fetchGoldRates() async => sampleGold;
  @override
  Future<double> fetchGstPercent() async => 3;
  @override
  Future<List<MetalRate>> fetchRateHistory(Metal metal, int days) async => const [];
}

final sampleReviews = ReviewSummary.fromJson({
  'averageRating': 4.6,
  'totalReviews': 3,
  'reviews': [
    {'_id': 'r1', 'userName': 'Priya S', 'rating': 5, 'title': 'Beautiful finish', 'comment': 'Lovely oxidised work and the weight matched exactly. Packed very well.', 'createdAt': '2026-10-12T10:00:00Z'},
    {'_id': 'r2', 'userName': 'Arun', 'rating': 4, 'title': 'Good value', 'comment': 'Slightly smaller than I expected but the quality is great.', 'createdAt': '2026-09-28T10:00:00Z'},
    {'_id': 'r3', 'userName': 'Meena', 'rating': 5, 'title': '', 'comment': 'Bought as a gift, everyone loved it.', 'createdAt': '2026-09-02T10:00:00Z'},
  ],
});
