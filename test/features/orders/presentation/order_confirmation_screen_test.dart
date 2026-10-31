import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/core/api/api_exception.dart';
import 'package:kv_silver_mobile/features/orders/data/models/order.dart';
import 'package:kv_silver_mobile/features/orders/data/order_repository.dart';
import 'package:kv_silver_mobile/features/orders/presentation/order_confirmation_screen.dart';

void main() {
  Future<void> pump(WidgetTester tester, Future<Order> Function() load) async {
    final container = ProviderContainer(overrides: [
      orderProvider.overrideWith((ref, id) => load()),
    ]);
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: OrderConfirmationScreen(orderId: 'abc')),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the order, the amount actually paid, and next steps', (tester) async {
    await pump(
      tester,
      () async => Order.fromJson({
        '_id': '64f1a2b3c4d5e6f7a8b9c0d1',
        'status': 'Pending',
        'paymentMethod': 'razorpay',
        'items': [
          {'productName': 'Anklet', 'quantity': 2, 'unitPrice': 1000, 'totalPrice': 2000},
        ],
        'taxAmount': 60,
        'deliveryFee': 150,
        'totalAmount': 2210,
        'createdAt': '2026-10-31T10:00:00Z',
      }),
    );

    expect(find.text('Order confirmed'), findsOneWidget);
    expect(find.textContaining('#A8B9C0D1'), findsOneWidget);
    expect(find.textContaining('31 October 2026'), findsOneWidget);
    expect(find.text('Qty: 2'), findsOneWidget);
    expect(find.text('₹2,000'), findsOneWidget);
    // The server's grand total, not a client recomputation.
    expect(find.text('Total paid'), findsOneWidget);
    expect(find.text('₹2,210'), findsOneWidget);
    expect(find.text('Hallmarking & packing'), findsOneWidget);
    expect(find.text('Resend email'), findsOneWidget);
    expect(find.text('View order'), findsOneWidget);
    expect(find.text('Download invoice'), findsOneWidget);
    expect(find.text('Keep shopping'), findsOneWidget);
  });

  testWidgets('without the order, order-only sections are hidden', (tester) async {
    await pump(tester, () async => throw const ServerException(404, 'Order not found'));

    expect(find.text('Order confirmed'), findsOneWidget);
    expect(find.text('Total paid'), findsNothing);
    expect(find.text('View order'), findsNothing);
    expect(find.text('Keep shopping'), findsOneWidget);
  });
}
