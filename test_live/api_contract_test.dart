// Live contract check: runs the app's real repositories and parsers against a
// deployed API. Not part of `flutter test` (which only runs test/). Run with:
//   flutter test test_live --dart-define=API_BASE_URL=https://api.kvsilverzone.com/api/v1
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/core/api/api_client.dart';
import 'package:kv_silver_mobile/core/api/api_exception.dart';
import 'package:kv_silver_mobile/features/catalog/data/catalog_repository.dart';
import 'package:kv_silver_mobile/features/checkout/data/checkout_repository.dart';
import 'package:kv_silver_mobile/features/delivery/delivery_check.dart';
import 'package:kv_silver_mobile/features/gift_vouchers/gift_vouchers_screen.dart';
import 'package:kv_silver_mobile/features/orders/presentation/invoice/invoice_view.dart';
import 'package:kv_silver_mobile/features/returns/returns.dart';
import 'package:kv_silver_mobile/features/reviews/reviews.dart';
import 'package:kv_silver_mobile/features/savings/data/savings_repository.dart';
import 'package:kv_silver_mobile/features/store_config/store_config.dart';

const base = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://api.kvsilverzone.com/api/v1');

void main() {
  final api = ApiClient(Dio(BaseOptions(
    baseUrl: base,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
  )));
  final catalog = CatalogRepository(api);

  group('public reads parse with the app models', () {
    test('catalogue: products, featured, one product, categories, tags', () async {
      final products = await catalog.fetchProducts(const ProductFilters(), page: 1, limit: 12);
      expect(products, isNotEmpty);
      expect(products.every((p) => p.id.isNotEmpty && p.name.isNotEmpty), isTrue);
      await catalog.fetchFeatured();
      final one = await catalog.fetchProduct(products.first.id);
      expect(one.id, products.first.id);
      expect(await catalog.fetchCategories(), isNotEmpty);
      await catalog.fetchTags();
      final reviews = await ReviewRepository(api).fetch(products.first.id);
      expect(reviews.totalReviews, greaterThanOrEqualTo(0));
    });

    test('rates, history, GST and delivery config', () async {
      await catalog.fetchSilverRates();
      await catalog.fetchGoldRates();
      await catalog.fetchRateHistory(Metal.silver, 30);
      await catalog.fetchRateHistory(Metal.gold, 30);
      expect(await catalog.fetchGstPercent(), greaterThan(0));
      final cfg = await CheckoutRepository(api).fetchDeliveryConfig();
      expect(cfg.chennai, greaterThanOrEqualTo(0));
    });

    test('store config, scheme plans, gift vouchers, invoice config, return policy', () async {
      final cfg = StoreConfig.fromJson((await api.get('/store-config') as Map).cast<String, dynamic>());
      expect(cfg.theme, isNotNull);
      await SavingsRepository(api).fetchPlans();
      parseGiftVouchers(await api.get('/gift-vouchers'));
      expect(InvoiceConfig.fromJson(await api.get('/invoice-config')).companyName, isNotEmpty);
      await ReturnsRepository(api).fetchClaimWindowHours();
      await api.get('/stall-config');
    });

    test('pincode check is real', () async {
      final ok = await DeliveryRepository(api).check('600040');
      expect(ok.available, isTrue);
      if (ok.verified) {
        expect(ok.city, 'Chennai');
        expect(ok.deliveryFee, isNotNull);
      }
      final bad = await DeliveryRepository(api).check('999999');
      if (bad.verified) expect(bad.available, isFalse);
    });
  });

  group('every signed-in endpoint the app calls exists (401 without a session, never 404)', () {
    const signedIn = <(String, String)>[
      ('get', '/users/me'), ('put', '/users/me'), ('get', '/users/me/addresses'),
      ('post', '/users/me/addresses'), ('put', '/users/me/addresses/1'), ('delete', '/users/me/addresses/1'),
      ('put', '/users/1/password'), ('post', '/users/me/phone/request-otp'), ('post', '/users/me/phone/verify-otp'),
      ('get', '/users/me/notifications'), ('post', '/users/me/notifications/1/read'),
      ('post', '/users/me/notifications/read-all'), ('post', '/users/me/push-tokens'), ('delete', '/users/me/push-tokens'),
      ('get', '/cart'), ('post', '/cart/items'), ('delete', '/cart/items/1'),
      ('get', '/wishlist'), ('post', '/wishlist/items'), ('delete', '/wishlist/items/1'),
      ('get', '/orders/me'), ('get', '/orders/1'), ('post', '/orders/1/resend-confirmation'),
      ('post', '/payments/create-order'), ('post', '/payments/verify'), ('post', '/coupons/apply'),
      ('get', '/returns/me'), ('post', '/returns'), ('post', '/products/1/reviews'),
      ('get', '/savings/my-schemes'), ('get', '/savings/passbook/X'), ('post', '/savings/enroll'),
      ('post', '/savings/enroll/request-otp'), ('post', '/savings/1/pay/create-order'), ('post', '/savings/1/pay/verify'),
    ];
    for (final (method, path) in signedIn) {
      test('$method $path', () async {
        final call = switch (method) {
          'get' => api.get(path),
          'post' => api.post(path, data: const <String, dynamic>{}),
          'put' => api.put(path, data: const <String, dynamic>{}),
          _ => api.delete(path, data: const <String, dynamic>{}),
        };
        await expectLater(call, throwsA(isA<AuthException>()));
      });
    }
  });

  group('public endpoints that need a body answer with a validation error, not 404', () {
    for (final path in [
      '/auth/login', '/auth/signup', '/auth/otp/request', '/auth/otp/verify',
      '/auth/forgot-password', '/auth/reset-password', '/contact',
    ]) {
      test('post $path', () async {
        try {
          await api.post(path, data: const <String, dynamic>{});
        } on ApiException catch (e) {
          expect(e is ServerException && e.statusCode == 404, isFalse, reason: e.message);
        }
      });
    }
  });
}
