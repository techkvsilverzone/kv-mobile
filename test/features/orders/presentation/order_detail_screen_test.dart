import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/features/orders/data/models/order.dart';
import 'package:kv_silver_mobile/features/orders/data/order_repository.dart';
import 'package:kv_silver_mobile/features/orders/presentation/order_detail_screen.dart';

Order _order(String status) => Order.fromJson({
      '_id': 'o1',
      'status': status,
      'paymentMethod': 'razorpay',
      'paymentStatus': 'paid',
      'items': [
        {'productName': 'Anklet', 'quantity': 1, 'unitPrice': 1000, 'totalPrice': 1000},
      ],
      'subtotal': 1000,
      'taxAmount': 30,
      'deliveryFee': 150,
      'giftWrapFee': 99,
      'totalAmount': 1279,
    });

void main() {
  Future<void> pump(WidgetTester tester, String status) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [orderProvider.overrideWith((ref, id) async => _order(status))],
      child: const MaterialApp(home: OrderDetailScreen(orderId: 'o1')),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the server totals including gift wrap and delivery', (tester) async {
    await pump(tester, 'Shipped');
    expect(find.text('Gift wrap'), findsOneWidget);
    expect(find.text('₹150'), findsOneWidget);
    expect(find.text('Total paid'), findsOneWidget);
    expect(find.text('₹1,279'), findsOneWidget);
    expect(find.text('Download invoice'), findsOneWidget);
    expect(find.text('Request a return'), findsNothing);
  });

  testWidgets('a delivered order offers a return', (tester) async {
    await pump(tester, 'Delivered');
    expect(find.text('Request a return'), findsOneWidget);
  });
}
