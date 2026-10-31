import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/features/catalog/data/catalog_repository.dart';
import 'package:kv_silver_mobile/features/catalog/presentation/product_detail_screen.dart';
import 'package:kv_silver_mobile/features/catalog/presentation/shop_screen.dart';
import 'package:kv_silver_mobile/features/gift_vouchers/gift_vouchers_screen.dart';
import 'package:kv_silver_mobile/features/offers/offers_screen.dart';
import 'package:kv_silver_mobile/features/recently_viewed/recently_viewed.dart';
import 'package:kv_silver_mobile/features/recently_viewed/recently_viewed_screen.dart';
import 'package:kv_silver_mobile/features/reviews/reviews.dart';
import 'package:kv_silver_mobile/features/reviews/reviews_page.dart';
import 'package:kv_silver_mobile/features/wishlist/wishlist.dart';
import 'package:kv_silver_mobile/features/wishlist/wishlist_screen.dart';
import 'package:kv_silver_mobile/features/catalog/application/catalog_providers.dart';
import 'fixtures.dart';
import 'screenshot.dart';
import 'shop_fixtures.dart';

void main() {
  final full = [
    catalogRepositoryProvider.overrideWithValue(ScreenCatalogRepo(products: sampleProducts)),
    productReviewsProvider.overrideWith((ref, id) async => sampleReviews),
    wishlistIdsProvider.overrideWith((ref) async => ['p1', 'p2', 'p4']),
    discountedProductsProvider.overrideWith((ref) async => sampleProducts.take(2).toList()),
    giftVouchersProvider.overrideWith((ref) async => parseGiftVouchers([
          {'_id': 'g1', 'amount': 1000, 'label': 'Silver gift card', 'description': 'Perfect for birthdays and small gifts.'},
          {'_id': 'g2', 'amount': 2500, 'tag': 'Popular', 'description': 'Our most gifted value.'},
          {'_id': 'g3', 'amount': 5000, 'description': 'For weddings and festivals.'},
        ])),
    recentlyViewedProvider.overrideWith((ref) => _Recent(['p3', 'p0', 'p5'])),
  ];
  final empty = [catalogRepositoryProvider.overrideWithValue(ScreenCatalogRepo())];
  final hang = [catalogRepositoryProvider.overrideWithValue(ScreenCatalogRepo(hang: true))];

  testWidgets('shop', (t) => screenshot(t, 'shop', const ShopScreen(), overrides: full));
  testWidgets('shop scrolled', (t) => screenshot(t, 'shop_scrolled', const ShopScreen(), overrides: full, scroll: 500));
  testWidgets('shop category', (t) => screenshot(t, 'shop_category', const ShopScreen(initialCategory: 'Bangles'), overrides: full));
  testWidgets('shop empty', (t) => screenshot(t, 'shop_empty', const ShopScreen(initialCategory: 'Coins'), overrides: empty));
  testWidgets('shop loading', (t) => screenshot(t, 'shop_loading', const ShopScreen(), overrides: hang));
  testWidgets('shop filters', (t) => screenshot(t, 'shop_filters', const ShopScreen(initialCategory: 'Bangles'),
      overrides: full, before: (t) async {
        await t.tap(find.text('Filters · 1'));
        await t.pump(const Duration(milliseconds: 600));
      }));
  testWidgets('shop sort', (t) => screenshot(t, 'shop_sort', const ShopScreen(), overrides: full, before: (t) async {
        await t.tap(find.text('Sort'));
        await t.pump(const Duration(milliseconds: 600));
      }));

  testWidgets('product', (t) => screenshot(t, 'product', const ProductDetailScreen(productId: 'p2'), overrides: full));
  testWidgets('product variants', (t) =>
      screenshot(t, 'product_variants', const ProductDetailScreen(productId: 'p0'), overrides: full, scroll: 300));
  testWidgets('product scrolled', (t) =>
      screenshot(t, 'product_scrolled', const ProductDetailScreen(productId: 'p0'), overrides: full, scroll: 900));
  testWidgets('product bottom', (t) =>
      screenshot(t, 'product_bottom', const ProductDetailScreen(productId: 'p0'), overrides: full, scroll: 1800));
  testWidgets('product sold out', (t) =>
      screenshot(t, 'product_soldout', const ProductDetailScreen(productId: 'p5'), overrides: full));
  testWidgets('reviews', (t) => screenshot(t, 'reviews',
      const ReviewsPage(productId: 'p0', productName: 'Peacock Anklet Pair'), overrides: full));

  testWidgets('wishlist', (t) => screenshot(t, 'wishlist', const WishlistScreen(), overrides: full));
  testWidgets('wishlist empty', (t) => screenshot(t, 'wishlist_empty', const WishlistScreen(),
      overrides: [...empty, wishlistIdsProvider.overrideWith((ref) async => const [])]));
  testWidgets('recently viewed', (t) => screenshot(t, 'recently_viewed', const RecentlyViewedScreen(), overrides: full));
  testWidgets('recently viewed empty', (t) => screenshot(t, 'recently_viewed_empty', const RecentlyViewedScreen(),
      overrides: [recentlyViewedProvider.overrideWith((ref) => _Recent(const []))]));
  testWidgets('offers', (t) => screenshot(t, 'offers', const OffersScreen(), overrides: full));
  testWidgets('offers scrolled', (t) => screenshot(t, 'offers_scrolled', const OffersScreen(), overrides: full, scroll: 500));
  testWidgets('gift vouchers', (t) => screenshot(t, 'gift_vouchers', const GiftVouchersScreen(), overrides: full));
  testWidgets('gift vouchers scrolled', (t) =>
      screenshot(t, 'gift_vouchers_scrolled', const GiftVouchersScreen(), overrides: full, scroll: 600));
}

class _Recent extends RecentlyViewedController {
  _Recent(List<String> ids) {
    state = ids;
  }
}
