/// The server's authoritative price breakdown, returned by
/// `POST /payments/create-order`.
///
/// The web app requests this and then **ignores it**, continuing to display its
/// own client-side math. That means a customer can be charged a different
/// number than the one on screen whenever the metal rate moved between
/// add-to-cart and checkout, with nothing to reconcile it. This app renders the
/// server's figures instead, and flags a mismatch before opening the payment
/// sheet.
class CheckoutBreakdown {
  const CheckoutBreakdown({
    required this.subtotal,
    required this.taxableSubtotal,
    required this.discount,
    required this.gstPercent,
    required this.taxAmount,
    required this.deliveryFee,
    required this.grandTotal,
    this.couponCode,
    this.deliveryZone,
  });

  final double subtotal;
  final double taxableSubtotal;
  final double discount;
  final double gstPercent;
  final double taxAmount;
  final double deliveryFee;

  /// The amount actually charged. Note the server also returns `totalWithTax`,
  /// which does **not** subtract the discount — do not display that one.
  final double grandTotal;

  final String? couponCode;
  final String? deliveryZone;

  factory CheckoutBreakdown.fromJson(Map<String, dynamic> json) => CheckoutBreakdown(
        subtotal: _d(json['subtotal']),
        taxableSubtotal: _d(json['taxableSubtotal']),
        discount: _d(json['discount']),
        gstPercent: _d(json['gstPercent']),
        taxAmount: _d(json['taxAmount']),
        deliveryFee: _d(json['deliveryFee']),
        grandTotal: _d(json['grandTotal']),
        couponCode: json['couponCode'] as String?,
        deliveryZone: json['deliveryZone'] as String?,
      );

  static double _d(dynamic v) => v is num ? v.toDouble() : 0;
}

/// `POST /payments/create-order` response. [amountInPaise] is what Razorpay
/// expects; [breakdown] is what the customer should see.
class RazorpayOrderDraft {
  const RazorpayOrderDraft({
    required this.id,
    required this.amountInPaise,
    required this.currency,
    required this.breakdown,
  });

  final String id;
  final int amountInPaise;
  final String currency;
  final CheckoutBreakdown breakdown;

  double get amountInRupees => amountInPaise / 100;

  factory RazorpayOrderDraft.fromJson(Map<String, dynamic> json) => RazorpayOrderDraft(
        id: (json['id'] ?? '').toString(),
        amountInPaise: (json['amount'] as num?)?.toInt() ?? 0,
        currency: (json['currency'] ?? 'INR') as String,
        breakdown: CheckoutBreakdown.fromJson(
          (json['breakdown'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
      );
}

class CouponResult {
  const CouponResult({required this.valid, required this.discount, required this.message});

  final bool valid;

  /// Rupees, already computed by the server. The coupon's type and value are
  /// never exposed to customers, so the client cannot recompute this.
  final double discount;
  final String message;

  factory CouponResult.fromJson(Map<String, dynamic> json) => CouponResult(
        valid: json['valid'] == true,
        discount: (json['discount'] as num?)?.toDouble() ?? 0,
        message: (json['message'] ?? '') as String,
      );
}

class DeliveryConfig {
  const DeliveryConfig({
    required this.chennai,
    required this.otherDistrict,
    required this.otherState,
  });

  final double chennai;
  final double otherDistrict;
  final double otherState;

  static const fallback = DeliveryConfig(chennai: 150, otherDistrict: 200, otherState: 250);

  factory DeliveryConfig.fromJson(Map<String, dynamic> json) => DeliveryConfig(
        chennai: (json['chennai'] as num?)?.toDouble() ?? fallback.chennai,
        otherDistrict: (json['otherDistrict'] as num?)?.toDouble() ?? fallback.otherDistrict,
        otherState: (json['otherState'] as num?)?.toDouble() ?? fallback.otherState,
      );

  /// Mirrors the server's `resolveDeliveryZone`: exact, lowercased, trimmed
  /// matches on city then state. Anything else falls into the most expensive
  /// zone, and pincode is irrelevant to the charge.
  double chargeFor({required String city, required String state}) {
    final c = city.trim().toLowerCase();
    final s = state.trim().toLowerCase();
    if (c == 'chennai') return chennai;
    if (s == 'tamil nadu' || s == 'tamilnadu') return otherDistrict;
    return otherState;
  }
}
