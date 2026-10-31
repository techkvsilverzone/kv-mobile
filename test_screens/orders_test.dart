import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/features/auth/application/address_controller.dart';
import 'package:kv_silver_mobile/features/cart/application/cart_controller.dart';
import 'package:kv_silver_mobile/features/cart/application/cart_totals.dart';
import 'package:kv_silver_mobile/features/cart/presentation/cart_screen.dart';
import 'package:kv_silver_mobile/features/catalog/application/catalog_providers.dart';
import 'package:kv_silver_mobile/features/checkout/data/checkout_repository.dart';
import 'package:kv_silver_mobile/features/checkout/data/models/checkout_breakdown.dart';
import 'package:kv_silver_mobile/features/checkout/presentation/checkout_screen.dart';
import 'package:kv_silver_mobile/features/orders/data/order_repository.dart';
import 'package:kv_silver_mobile/features/orders/presentation/order_confirmation_screen.dart';
import 'package:kv_silver_mobile/features/orders/presentation/order_detail_screen.dart';
import 'package:kv_silver_mobile/features/orders/presentation/orders_screen.dart';
import 'package:kv_silver_mobile/features/returns/request_return_dialog.dart';
import 'package:kv_silver_mobile/features/returns/returns.dart';
import 'package:kv_silver_mobile/features/returns/returns_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fixtures.dart';
import 'orders_fixtures.dart';
import 'screenshot.dart';

void main() {
  setUp(() {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('razorpay_flutter'), (_) async => null);
  });

  final base = [gstPercentProvider.overrideWith((ref) async => 3)];
  List cart({bool oos = false, bool wrap = false}) => [
        ...base,
        cartProvider.overrideWith((ref) => sampleCart(outOfStock: oos)),
        cartRefreshProvider.overrideWith((ref) async {}),
        if (wrap) giftWrapProvider.overrideWith((ref) => const GiftWrap(enabled: true, message: 'Happy Diwali, Amma!')),
      ];
  List checkout({bool saved = true}) => [
        ...cart(wrap: true),
        addressListProvider.overrideWith((ref) => AddressListController(FakeAddressRepo(saved ? sampleAddresses : []))),
        deliveryConfigProvider.overrideWith((ref) async => DeliveryConfig.fallback),
        checkoutRepositoryProvider.overrideWithValue(FakeCheckoutRepo()),
      ];
  final orders = [
    myOrdersProvider.overrideWith((ref) async => [deliveredOrder(), sampleOrder(4), sampleOrder(3, status: 'Pending'), sampleOrder(1, status: 'Cancelled')]),
    orderProvider.overrideWith((ref, id) async => id == 'shipped' ? sampleOrder(4) : deliveredOrder()),
  ];
  final returns = [
    returnsRepositoryProvider.overrideWithValue(FakeReturnsRepo()),
    myReturnsProvider.overrideWith((ref) async => sampleReturns),
  ];

  testWidgets('cart', (t) => screenshot(t, 'cart', const CartScreen(), overrides: cart().cast()));
  testWidgets('cart scrolled', (t) => screenshot(t, 'cart_scrolled', const CartScreen(), overrides: cart(wrap: true).cast(), scroll: 500));
  testWidgets('cart out of stock', (t) => screenshot(t, 'cart_oos', const CartScreen(), overrides: cart(oos: true).cast()));
  testWidgets('cart empty', (t) => screenshot(t, 'cart_empty', const CartScreen(), overrides: base.cast()));

  testWidgets('checkout', (t) => screenshot(t, 'checkout', const CheckoutScreen(), overrides: checkout().cast()));
  testWidgets('checkout scrolled', (t) => screenshot(t, 'checkout_scrolled', const CheckoutScreen(), overrides: checkout().cast(), scroll: 600));
  testWidgets('checkout new address', (t) => screenshot(t, 'checkout_form', const CheckoutScreen(), overrides: checkout(saved: false).cast()));
  testWidgets('checkout address sheet', (t) => screenshot(t, 'checkout_address_sheet', const CheckoutScreen(),
      overrides: checkout().cast(), before: (t) async {
        await t.tap(find.text('Change'));
        await t.pump(const Duration(milliseconds: 100));
        await t.pump(const Duration(milliseconds: 600));
      }));
  testWidgets('checkout coupon sheet', (t) => screenshot(t, 'checkout_coupon_sheet', const CheckoutScreen(),
      overrides: checkout().cast(), before: (t) async {
        await t.tap(find.text('Apply coupon'));
        await t.pump(const Duration(milliseconds: 100));
        await t.pump(const Duration(milliseconds: 600));
        await t.enterText(find.byType(TextField).last, 'DIWALI');
        await t.tap(find.text('Apply').last);
        await t.pump(const Duration(milliseconds: 300));
      }));
  testWidgets('checkout confirm sheet', (t) => screenshot(t, 'checkout_confirm', const CheckoutScreen(),
      overrides: checkout().cast(), before: (t) async {
        await t.tap(find.textContaining('Pay ₹'));
        await t.pump(const Duration(milliseconds: 100));
        await t.pump(const Duration(milliseconds: 600));
      }));

  testWidgets('orders', (t) => screenshot(t, 'orders', const OrdersScreen(), overrides: orders.cast()));
  testWidgets('order detail', (t) => screenshot(t, 'order_detail', const OrderDetailScreen(orderId: 'd'), overrides: orders.cast()));
  testWidgets('order detail scrolled',
      (t) => screenshot(t, 'order_detail_scrolled', const OrderDetailScreen(orderId: 'd'), overrides: orders.cast(), scroll: 700));
  testWidgets('order detail shipped',
      (t) => screenshot(t, 'order_detail_shipped', const OrderDetailScreen(orderId: 'shipped'), overrides: orders.cast()));
  testWidgets('confirmation', (t) => screenshot(t, 'order_confirmation', const OrderConfirmationScreen(orderId: 'd'), overrides: orders.cast()));
  testWidgets('confirmation scrolled', (t) => screenshot(t, 'order_confirmation_scrolled',
      const OrderConfirmationScreen(orderId: 'd'), overrides: orders.cast(), scroll: 500));

  testWidgets('returns', (t) => screenshot(t, 'returns', const ReturnsScreen(), overrides: returns.cast()));
  testWidgets('request return', (t) => screenshot(t, 'return_request', RequestReturnScreen(order: deliveredOrder()),
      overrides: returns.cast(), before: (t) async {
        await t.tap(find.text('Peacock Anklet Pair'));
        await t.pump(const Duration(seconds: 1));
      }));
  testWidgets('request return scrolled', (t) => screenshot(t, 'return_request_scrolled', RequestReturnScreen(order: deliveredOrder()),
      overrides: returns.cast(), scroll: 400));
  testWidgets('request return submitted', (t) => screenshot(t, 'return_submitted', RequestReturnScreen(order: deliveredOrder()),
      overrides: returns.cast(), before: (t) async {
        await t.tap(find.text('Peacock Anklet Pair'));
        await t.enterText(find.byType(TextField).first, 'Clasp broken on arrival');
        await t.tap(find.text('Submit request'));
        await t.pump(const Duration(milliseconds: 300));
      }));
  testWidgets('returns empty', (t) => screenshot(t, 'returns_empty', const ReturnsScreen(),
      overrides: [myReturnsProvider.overrideWith((ref) async => const <ReturnRequest>[])]));
}
