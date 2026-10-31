import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/features/checkout/data/checkout_repository.dart';
import 'package:kv_silver_mobile/features/cart/application/cart_controller.dart';
import 'package:kv_silver_mobile/features/cart/presentation/cart_screen.dart';
import 'package:kv_silver_mobile/features/catalog/application/catalog_providers.dart';
import 'package:kv_silver_mobile/features/catalog/data/models/product.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../cart_controller_test.dart' show FakeCartRepository;

Product _product({bool inStock = true}) => Product.fromJson({
      '_id': 'p1',
      'name': 'Silver Anklet',
      'weight': 20,
      'purity': '925',
      'price': 1000,
      'listedPrice': 1000,
      'isFixedPrice': true,
      'inStock': inStock,
      'stockAvailable': inStock ? 5 : 0,
    });

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpCart(WidgetTester tester, void Function(CartController c) fill) async {
    final controller = CartController(FakeCartRepository(), isAuthenticated: () => false);
    fill(controller);
    final container = ProviderContainer(overrides: [
      cartProvider.overrideWith((ref) => controller),
      gstPercentProvider.overrideWith((ref) async => 3),
    ]);
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: CartScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('GST applies to products only; gift vouchers are GST-inclusive', (tester) async {
    await pumpCart(tester, (c) {
      c.add(_product(), unitPrice: 1000);
      c.addVoucher(id: 'v1', name: 'Gift Voucher', price: 500);
    });

    expect(find.text('Shopping Cart'), findsOneWidget);
    expect(find.text('20.0 g • 925'), findsOneWidget);
    // Subtotal 1,500; GST 3% of the 1,000 product line only; total 1,530.
    expect(find.text('₹1,500'), findsOneWidget);
    expect(find.text('₹30'), findsOneWidget);
    expect(find.text('₹1,530'), findsOneWidget);
    expect(find.text('Calculated at checkout'), findsOneWidget);
    expect(find.text('Proceed to Checkout'), findsOneWidget);
  });

  testWidgets('gift wrapping adds the fee line and a message field', (tester) async {
    await pumpCart(tester, (c) => c.add(_product(), unitPrice: 1000));
    expect(find.text('Personalized Message'), findsNothing);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('Personalized Message'), findsOneWidget);
    expect(find.text('Gift Wrapping'), findsNWidgets(2)); // card title + summary line
    expect(find.text('₹1,129'), findsOneWidget); // 1,000 + 30 GST + 99
  });

  test('checkout sends gift wrap as the API expects', () {
    expect(const GiftWrapChoice('  Happy Diwali ').toJson(), {'giftWrap': true, 'giftMessage': 'Happy Diwali'});
    expect(const GiftWrapChoice('').toJson(), {'giftWrap': true});
  });

  testWidgets('an out-of-stock line blocks checkout', (tester) async {
    await pumpCart(tester, (c) => c.add(_product(inStock: false), unitPrice: 1000));

    expect(find.text('Out of stock — remove to continue'), findsOneWidget);
    expect(find.text('Remove out-of-stock items'), findsOneWidget);
    expect(find.text('One or more items are out of stock. Please remove them to proceed.'),
        findsOneWidget);
  });

  testWidgets('empty cart matches the web copy', (tester) async {
    await pumpCart(tester, (_) {});
    expect(find.text('Your Cart is Empty'), findsOneWidget);
    expect(find.text('Start Shopping'), findsOneWidget);
  });
}
