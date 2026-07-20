import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/features/orders/data/models/order.dart';

Map<String, dynamic> orderJson([Map<String, dynamic> overrides = const {}]) => {
      '_id': '665f00aabbccddee11223344',
      'invoiceNumber': 'INV-2026-000123',
      'status': 'Shipped',
      'paymentMethod': 'razorpay',
      'paymentStatus': 'Paid',
      'subtotal': 2000,
      'taxAmount': 57,
      'deliveryFee': 150,
      'couponDiscount': 100,
      'grandTotal': 2107,
      'totalAmount': 2107,
      'couponCode': 'SAVE10',
      'createdAt': '2026-07-20T10:00:00.000Z',
      'items': [
        {'productName': 'Silver Anklet', 'quantity': 2, 'unitPrice': 1000, 'totalPrice': 2000, 'weight': 20},
      ],
      'shippingAddress': {
        'name': 'Asha K',
        'line1': '12 MG Road',
        'city': 'Erode',
        'state': 'Tamil Nadu',
        'pincode': '638001',
        'phone': '9876543210',
      },
      ...overrides,
    };

void main() {
  group('status parsing', () {
    test('maps the capitalised wire literals', () {
      expect(orderStatusFrom('Pending'), OrderStatus.pending);
      expect(orderStatusFrom('Processing'), OrderStatus.processing);
      expect(orderStatusFrom('Shipped'), OrderStatus.shipped);
      expect(orderStatusFrom('Delivered'), OrderStatus.delivered);
      expect(orderStatusFrom('Cancelled'), OrderStatus.cancelled);
    });

    test('an unrecognised status does not crash the screen', () {
      expect(orderStatusFrom('Refunded'), OrderStatus.unknown);
      expect(orderStatusFrom(null), OrderStatus.unknown);
    });

    test('cancelled sits outside the fulfilment timeline', () {
      expect(OrderStatus.cancelled.stepIndex, -1);
      expect(OrderStatus.pending.stepIndex, 0);
      expect(OrderStatus.delivered.stepIndex, 3);
    });
  });

  group('Order.fromJson', () {
    test('reads the stored totals', () {
      final o = Order.fromJson(orderJson());
      expect(o.subtotal, 2000);
      expect(o.taxAmount, 57);
      expect(o.deliveryFee, 150);
      expect(o.couponDiscount, 100);
      expect(o.grandTotal, 2107);
    });

    test('falls back to totalAmount when grandTotal is absent', () {
      final json = orderJson()..remove('grandTotal');
      expect(Order.fromJson(json).grandTotal, 2107);
    });

    test('parses items and the shipping address', () {
      final o = Order.fromJson(orderJson());
      expect(o.items.single.productName, 'Silver Anklet');
      expect(o.items.single.quantity, 2);
      expect(o.address?.city, 'Erode');
    });

    test('accepts the legacy address aliases older orders carry', () {
      final o = Order.fromJson(orderJson({
        'shippingAddress': {
          'firstName': 'Asha',
          'lastName': 'K',
          'address': '12 MG Road',
          'city': 'Erode',
          'state': 'Tamil Nadu',
          'pincode': '638001',
          'phone': '9876543210',
        },
      }));
      expect(o.address?.name, 'Asha K');
      expect(o.address?.line1, '12 MG Road');
    });

    test('labels the payment method for customers', () {
      expect(Order.fromJson(orderJson()).paymentMethodLabel, 'Paid online');
      expect(
        Order.fromJson(orderJson({'paymentMethod': 'cod'})).paymentMethodLabel,
        'Cash on delivery',
      );
    });

    test('shortId takes the last six characters for display', () {
      expect(Order.fromJson(orderJson()).shortId, '223344');
    });
  });
}
