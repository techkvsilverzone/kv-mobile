// Fakes for the cart / checkout / orders / returns screenshots.
import 'package:kv_silver_mobile/features/auth/data/address_repository.dart';
import 'package:kv_silver_mobile/features/auth/data/models/address.dart';
import 'package:kv_silver_mobile/features/cart/application/cart_controller.dart';
import 'package:kv_silver_mobile/features/cart/data/cart_repository.dart';
import 'package:kv_silver_mobile/features/cart/data/models/cart_item.dart';
import 'package:kv_silver_mobile/features/checkout/data/checkout_repository.dart';
import 'package:kv_silver_mobile/features/checkout/data/models/checkout_breakdown.dart';
import 'package:kv_silver_mobile/features/orders/data/models/order.dart';
import 'package:kv_silver_mobile/features/returns/returns.dart';
import 'fixtures.dart';

class FakeCartRepo implements CartRepository {
  @override
  Future<void> putItem({required String productId, required int quantity}) async {}
  @override
  Future<void> removeItem(String productId) async {}
  @override
  Future<List<({String productId, int quantity})>> fetchItems() async => const [];
}

/// Cart with a variant line, a plain line and a gift voucher ([outOfStock] adds one more).
CartController sampleCart({bool outOfStock = false}) {
  final c = CartController(FakeCartRepo(), isAuthenticated: () => false);
  final p0 = sampleProducts[0];
  c.add(p0, unitPrice: 2450, variant: p0.variants[1]);
  c.add(sampleProducts[1], unitPrice: 1180, quantity: 2);
  c.addVoucher(id: 'gv1', name: 'KV Gift Voucher ₹1,000', price: 1000);
  if (outOfStock) c.add(sampleProducts[5], unitPrice: 3800);
  return c;
}

const sampleAddresses = [
  Address(
      id: 'a1', label: 'Home', firstName: 'Vinoth', lastName: 'Kumar', address: '12, Anna Salai, T. Nagar',
      city: 'Chennai', state: 'Tamil Nadu', pincode: '600017', phone: '9876543210', isDefault: true),
  Address(
      id: 'a2', label: 'Office', firstName: 'Vinoth', lastName: 'Kumar', address: '4th Floor, Tidel Park, Taramani',
      city: 'Chennai', state: 'Tamil Nadu', pincode: '600113', phone: '9876543210'),
];

class FakeAddressRepo implements AddressRepository {
  FakeAddressRepo(this.items);
  final List<Address> items;
  @override
  Future<List<Address>> list() async => items;
  @override
  Future<Address> create(Address address) async => address;
  @override
  Future<Address> update(String id, Address address) async => address;
  @override
  Future<void> delete(String id) async {}
}

Order deliveredOrder() => Order.fromJson({
      '_id': '67200000000009',
      'invoiceNumber': 'INV-2026-000129',
      'status': 'Delivered',
      'paymentMethod': 'razorpay',
      'paymentStatus': 'paid',
      'items': [
        {'productId': 'p1', 'productName': 'Peacock Anklet Pair', 'quantity': 1, 'unitPrice': 2450, 'totalPrice': 2450, 'weight': 25},
        {'productId': 'p2', 'productName': 'Lakshmi Silver Coin 10g', 'quantity': 2, 'unitPrice': 1180, 'totalPrice': 2360},
      ],
      'subtotal': 4810,
      'taxAmount': 140.7,
      'deliveryFee': 150,
      'couponDiscount': 120,
      'couponCode': 'DIWALI5',
      'giftWrapFee': 99,
      'giftMessage': 'Happy Diwali, Amma!',
      'totalAmount': 5079.7,
      'createdAt': '2026-10-20T10:30:00Z',
      'deliveredAt': '2026-10-25T15:00:00Z',
      'shippingAddress': {
        'name': 'Vinoth Kumar', 'line1': '12, Anna Salai, T. Nagar', 'city': 'Chennai', 'state': 'Tamil Nadu',
        'pincode': '600017', 'phone': '9876543210'
      },
    });

final sampleReturns = [
  ReturnRequest.fromJson({
    'id': 'r00000a1b2c3', 'orderId': '67200000000009', 'reason': 'Received a damaged anklet clasp',
    'status': 'Pending', 'refundAmount': 2450, 'faultType': 'kv_fault', 'videoStatus': 'awaiting',
    'videoReferenceCode': 'KV-7Q4M', 'createdAt': '2026-10-26T09:00:00Z',
  }),
  ReturnRequest.fromJson({
    'id': 'r00000d4e5f6', 'orderId': '67200000000005', 'reason': 'Size too small for my wrist',
    'status': 'Approved', 'refundAmount': 0, 'faultType': 'customer_preference', 'videoStatus': 'not_required',
    'createdAt': '2026-10-12T09:00:00Z',
  }),
  ReturnRequest.fromJson({
    'id': 'r00000g7h8i9', 'orderId': '67200000000003', 'reason': 'Wrong design delivered',
    'status': 'Completed', 'refundAmount': 1180, 'faultType': 'kv_fault', 'videoStatus': 'received',
    'createdAt': '2026-09-30T09:00:00Z',
  }),
];

class FakeReturnsRepo implements ReturnsRepository {
  @override
  Future<List<ReturnRequest>> fetchMine() async => sampleReturns;
  @override
  Future<int?> fetchClaimWindowHours() async => 48;
  @override
  Future<VideoInstructions?> create({
    required String orderId,
    required bool kvFault,
    required String reason,
    required String description,
    required List<ReturnItemInput> items,
  }) async =>
      kvFault ? const VideoInstructions('+91 88256 49680', 'KV-7Q4M', 48) : null;
}

class FakeCheckoutRepo implements CheckoutRepository {
  @override
  Future<CouponResult> applyCoupon({required String code, required double orderAmount}) async =>
      const CouponResult(valid: false, discount: 0, message: 'Coupon has expired');
  @override
  Future<DeliveryConfig> fetchDeliveryConfig() async => DeliveryConfig.fallback;
  @override
  Future<RazorpayOrderDraft> createRazorpayOrder({
    required List<CartItem> items,
    required Address address,
    String? couponCode,
    GiftWrapChoice? giftWrap,
  }) async =>
      RazorpayOrderDraft.fromJson({
        'id': 'order_X', 'amount': 625480, 'currency': 'INR',
        'breakdown': {
          'subtotal': 5860, 'taxableSubtotal': 4860, 'discount': 0, 'gstPercent': 3, 'taxAmount': 145.8,
          'deliveryFee': 150, 'giftWrapFee': 99, 'grandTotal': 6254.8, 'deliveryZone': 'chennai',
        },
      });
  @override
  Future<String> verifyPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
    required List<CartItem> items,
    required Address address,
    String? couponCode,
    GiftWrapChoice? giftWrap,
  }) async =>
      'o1';
}
