import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/core/format/currency.dart';
import 'package:kv_silver_mobile/features/auth/application/address_controller.dart';
import 'package:kv_silver_mobile/features/auth/data/address_repository.dart';
import 'package:kv_silver_mobile/features/auth/data/models/address.dart';
import 'package:kv_silver_mobile/features/cart/application/cart_controller.dart';
import 'package:kv_silver_mobile/features/cart/data/models/cart_item.dart';
import 'package:kv_silver_mobile/features/catalog/application/catalog_providers.dart';
import 'package:kv_silver_mobile/features/catalog/data/models/product.dart';
import 'package:kv_silver_mobile/features/checkout/data/checkout_repository.dart';
import 'package:kv_silver_mobile/features/checkout/data/models/checkout_breakdown.dart';
import 'package:kv_silver_mobile/features/checkout/presentation/checkout_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../cart/cart_controller_test.dart' show FakeCartRepository;

class _Addresses implements AddressRepository {
  _Addresses(this.items);
  final List<Address> items;
  @override
  Future<List<Address>> list() async => items;
  @override
  Future<Address> create(Address a) async => a;
  @override
  Future<Address> update(String id, Address a) async => a;
  @override
  Future<void> delete(String id) async {}
}

class _Checkout implements CheckoutRepository {
  Address? pricedAddress;
  @override
  Future<CouponResult> applyCoupon({required String code, required double orderAmount}) async =>
      const CouponResult(valid: true, discount: 50, message: 'Saved');
  @override
  Future<DeliveryConfig> fetchDeliveryConfig() async => DeliveryConfig.fallback;
  @override
  Future<RazorpayOrderDraft> createRazorpayOrder(
      {required List<CartItem> items, required Address address, String? couponCode, GiftWrapChoice? giftWrap}) async {
    pricedAddress = address;
    return RazorpayOrderDraft.fromJson({
      'id': 'order_1', 'amount': 123400, 'currency': 'INR',
      'breakdown': {'subtotal': 1000, 'gstPercent': 3, 'taxAmount': 30, 'deliveryFee': 150, 'grandTotal': 1234},
    });
  }

  @override
  Future<String> verifyPayment(
          {required String razorpayOrderId,
          required String razorpayPaymentId,
          required String razorpaySignature,
          required List<CartItem> items,
          required Address address,
          String? couponCode,
          GiftWrapChoice? giftWrap}) async =>
      'o1';
}

const _home = Address(
    id: 'a1', label: 'Home', firstName: 'Asha', lastName: 'R', address: '12 Anna Salai', city: 'Chennai',
    state: 'Tamil Nadu', pincode: '600017', phone: '9876543210', isDefault: true);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('razorpay_flutter'), (_) async => null);
  });

  Future<_Checkout> pump(WidgetTester tester, List<Address> saved) async {
    final cart = CartController(FakeCartRepository(), isAuthenticated: () => false)
      ..add(
          Product.fromJson({'_id': 'p1', 'name': 'Anklet', 'weight': 20, 'price': 1000, 'listedPrice': 1000, 'isFixedPrice': true, 'inStock': true, 'stockAvailable': 5}),
          unitPrice: 1000);
    final repo = _Checkout();
    final container = ProviderContainer(overrides: [
      cartProvider.overrideWith((ref) => cart),
      gstPercentProvider.overrideWith((ref) async => 3),
      addressListProvider.overrideWith((ref) => AddressListController(_Addresses(saved))),
      deliveryConfigProvider.overrideWith((ref) async => DeliveryConfig.fallback),
      checkoutRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MaterialApp(home: CheckoutScreen())));
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('a saved address shows as a card and is what the server prices', (tester) async {
    final repo = await pump(tester, [_home]);
    expect(find.text('Asha R'), findsOneWidget);
    expect(find.text('Default'), findsOneWidget);
    expect(find.text('First name'), findsNothing);

    await tester.tap(find.textContaining('Pay ₹'));
    // The bar's spinner keeps running behind the sheet, so pump rather than settle.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(repo.pricedAddress?.pincode, '600017');
    // The confirm sheet charges the server's amount, not the local estimate.
    expect(find.text('Confirm your order'), findsOneWidget);
    expect(find.text('Pay ${formatInr(1234)}'), findsOneWidget);
  });

  testWidgets('without saved addresses the form is validated before pricing', (tester) async {
    final repo = await pump(tester, const []);
    expect(find.text('First name'), findsOneWidget);

    await tester.tap(find.textContaining('Pay ₹'));
    await tester.pumpAndSettle();
    expect(repo.pricedAddress, isNull);
    expect(find.text('Check your delivery address'), findsOneWidget);
  });

  testWidgets('a coupon applied from the sheet shows as a removable chip', (tester) async {
    await pump(tester, [_home]);
    await tester.tap(find.text('Apply coupon'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Coupon code'), 'diwali');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(find.text('DIWALI applied'), findsOneWidget);
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Apply coupon'), findsOneWidget);
  });
}
