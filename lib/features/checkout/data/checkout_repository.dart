import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../auth/data/models/address.dart';
import '../../cart/data/models/cart_item.dart';
import 'models/checkout_breakdown.dart';

/// Raised when `/payments/verify` fails **after** Razorpay reported success —
/// money has moved but no order exists. Distinct from other failures because
/// the recovery is entirely different: never tell the customer to just retry.
class PaymentVerificationException implements Exception {
  const PaymentVerificationException({
    required this.message,
    required this.razorpayPaymentId,
    required this.razorpayOrderId,
  });

  final String message;
  final String razorpayPaymentId;
  final String razorpayOrderId;

  @override
  String toString() => message;
}

/// Gift wrap as checkout sends it. The server owns the fee.
class GiftWrapChoice {
  const GiftWrapChoice(this.message);
  final String message;
  Map<String, dynamic> toJson() => {'giftWrap': true, if (message.trim().isNotEmpty) 'giftMessage': message.trim()};
}

class CheckoutRepository {
  CheckoutRepository(this._api);

  final ApiClient _api;

  Future<CouponResult> applyCoupon({required String code, required double orderAmount}) async {
    final data = await _api.post('/coupons/apply', data: {
      'code': code.trim().toUpperCase(),
      'orderAmount': orderAmount,
    });
    return CouponResult.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<DeliveryConfig> fetchDeliveryConfig() async {
    try {
      final data = await _api.get('/delivery-config');
      final payload = data is Map ? data['data'] : null;
      if (payload is Map) return DeliveryConfig.fromJson(payload.cast<String, dynamic>());
    } catch (_) {
      // Fall through — a config outage must not block checkout.
    }
    return DeliveryConfig.fallback;
  }

  /// Prices the order server-side. No amount is sent: the client's totals are
  /// display-only and the server recomputes from the line items.
  ///
  /// The full [address] is sent, not just the pincode, because the delivery fee
  /// is resolved from city/state — sending only a pincode yields a zero fee
  /// here and a different total at verify.
  Future<RazorpayOrderDraft> createRazorpayOrder({
    required List<CartItem> items,
    required Address address,
    String? couponCode,
    GiftWrapChoice? giftWrap,
  }) async {
    final data = await _api.post('/payments/create-order', data: {
      ...?giftWrap?.toJson(),
      'items': items.map((e) => e.toOrderLine()).toList(),
      if (couponCode != null && couponCode.isNotEmpty) 'couponCode': couponCode,
      'pincode': address.pincode,
      'shippingAddress': _addressPayload(address),
    });
    return RazorpayOrderDraft.fromJson((data as Map).cast<String, dynamic>());
  }

  /// Confirms the payment and creates the order.
  ///
  /// The SDK reports snake_case ids; this endpoint expects camelCase, so they
  /// are mapped here rather than at the call site.
  Future<String> verifyPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
    required List<CartItem> items,
    required Address address,
    String? couponCode,
    GiftWrapChoice? giftWrap,
  }) async {
    try {
      final data = await _api.post('/payments/verify', data: {
        'razorpayOrderId': razorpayOrderId,
        'razorpayPaymentId': razorpayPaymentId,
        'razorpaySignature': razorpaySignature,
        'orderData': {
          'items': items.map((e) => e.toOrderLine()).toList(),
          'shippingAddress': _addressPayload(address),
          'paymentMethod': 'razorpay',
          if (couponCode != null && couponCode.isNotEmpty) 'couponCode': couponCode,
          ...?giftWrap?.toJson(),
        },
      });

      final map = (data as Map).cast<String, dynamic>();
      // A 200 with success:false is a real failure — the web app has no `else`
      // branch here and silently does nothing.
      if (map['success'] != true) {
        throw PaymentVerificationException(
          message: (map['message'] ?? 'Payment verification failed.') as String,
          razorpayPaymentId: razorpayPaymentId,
          razorpayOrderId: razorpayOrderId,
        );
      }
      return (map['orderId'] ?? '').toString();
    } on ApiException catch (e) {
      throw PaymentVerificationException(
        message: e.message,
        razorpayPaymentId: razorpayPaymentId,
        razorpayOrderId: razorpayOrderId,
      );
    }
  }

  /// The server accepts `firstName`/`lastName`/`address` as legacy aliases for
  /// `name`/`line1`, which is what the address book already stores.
  Map<String, dynamic> _addressPayload(Address a) => {
        'firstName': a.firstName,
        'lastName': a.lastName,
        'address': a.address,
        'city': a.city,
        'state': a.state,
        'pincode': a.pincode,
        'phone': a.phone,
        'country': 'India',
      };
}

final checkoutRepositoryProvider = Provider<CheckoutRepository>((ref) {
  return CheckoutRepository(ref.watch(apiClientProvider));
});

final deliveryConfigProvider = FutureProvider<DeliveryConfig>((ref) {
  return ref.watch(checkoutRepositoryProvider).fetchDeliveryConfig();
});
