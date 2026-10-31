import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/features/orders/data/models/order.dart';
import 'package:kv_silver_mobile/features/orders/presentation/invoice/invoice_view.dart';

Order _order(Map<String, dynamic> extra) => Order.fromJson({
      '_id': '1234567890123',
      'status': 'Delivered',
      'paymentMethod': 'razorpay',
      'items': [
        {'productName': 'Anklet', 'quantity': 2, 'unitPrice': 1000, 'totalPrice': 2000},
      ],
      'couponDiscount': 200,
      'couponCode': 'DIWALI',
      'taxAmount': 54,
      'totalAmount': 1854,
      'createdAt': '2026-10-31T10:00:00Z',
      'shippingAddress': {
        'name': 'Asha', 'line1': '1 Main St', 'city': 'Chennai', 'state': 'TN',
        'pincode': '600001', 'phone': '9876543210'
      },
      ...extra,
    });

void main() {
  test('totals and GST percent follow the web invoice', () {
    final t = InvoiceTotals(_order({}));
    expect(t.subtotal, 2000);
    expect(t.gstPercent, 3);
    expect(InvoiceTotals(_order({'taxAmount': 0, 'couponDiscount': 2000})).gstPercent, 3);
  });

  test('invoice number falls back to the last 10 id characters, upper-cased', () {
    expect(invoiceNumberOf(_order({'_id': 'abcdefghijklmn'})), 'EFGHIJKLMN');
    expect(invoiceNumberOf(_order({'invoiceNumber': 'INV-2026-000123'})), 'INV-2026-000123');
  });

  testWidgets('online order shows ship-to; in-store shows sold-at', (tester) async {
    Future<void> pump(Order o) => tester.pumpWidget(MaterialApp(
        home: SingleChildScrollView(child: InvoiceView(order: o, config: const InvoiceConfig()))));

    await pump(_order({}));
    expect(find.text('SHIP TO'), findsOneWidget);
    expect(find.text('Discount (DIWALI)'), findsOneWidget);
    expect(find.text('GST (3%)'), findsOneWidget);
    expect(find.text('Online (Razorpay)'), findsNothing); // inside a Text.rich
    expect(find.textContaining('Online (Razorpay)', findRichText: true), findsOneWidget);

    await pump(_order({'channel': 'OFFLINE', 'saleLocation': 'Anna Nagar stall', 'soldBy': {'name': 'Ravi'}}));
    expect(find.text('SOLD AT'), findsOneWidget);
    expect(find.text('Anna Nagar stall\nBilled by Ravi'), findsOneWidget);
  });
}
