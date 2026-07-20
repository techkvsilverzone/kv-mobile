import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/features/checkout/data/models/checkout_breakdown.dart';

void main() {
  group('DeliveryConfig.chargeFor', () {
    const config = DeliveryConfig(chennai: 150, otherDistrict: 200, otherState: 250);

    test('matches Chennai case-insensitively and ignoring surrounding space', () {
      expect(config.chargeFor(city: 'Chennai', state: 'Tamil Nadu'), 150);
      expect(config.chargeFor(city: ' chennai ', state: 'Tamil Nadu'), 150);
    });

    test('falls to the district rate elsewhere in Tamil Nadu', () {
      expect(config.chargeFor(city: 'Erode', state: 'Tamil Nadu'), 200);
      expect(config.chargeFor(city: 'Erode', state: 'tamilnadu'), 200);
    });

    test('anything else is the out-of-state rate', () {
      expect(config.chargeFor(city: 'Mumbai', state: 'Maharashtra'), 250);
      // Exact match only — "chennai city" is not Chennai, matching the server.
      expect(config.chargeFor(city: 'chennai city', state: 'Karnataka'), 250);
    });
  });

  group('CheckoutBreakdown.fromJson', () {
    test('reads the server totals', () {
      final b = CheckoutBreakdown.fromJson({
        'subtotal': 2000,
        'taxableSubtotal': 2000,
        'discount': 100,
        'gstPercent': 3,
        'taxAmount': 57,
        'deliveryFee': 150,
        'grandTotal': 2107,
        'couponCode': 'SAVE10',
        'deliveryZone': 'chennai',
      });

      expect(b.subtotal, 2000);
      expect(b.discount, 100);
      expect(b.grandTotal, 2107);
      expect(b.couponCode, 'SAVE10');
    });

    test('defaults missing numbers to zero rather than throwing', () {
      final b = CheckoutBreakdown.fromJson(const {});
      expect(b.grandTotal, 0);
      expect(b.gstPercent, 0);
    });
  });

  group('RazorpayOrderDraft', () {
    test('converts the paise amount to rupees for display', () {
      final draft = RazorpayOrderDraft.fromJson({
        'id': 'order_123',
        'amount': 210700,
        'currency': 'INR',
        'breakdown': {'grandTotal': 2107},
      });

      expect(draft.id, 'order_123');
      expect(draft.amountInPaise, 210700);
      expect(draft.amountInRupees, 2107);
      expect(draft.breakdown.grandTotal, 2107);
    });
  });

  group('CouponResult', () {
    test('reads the pre-computed discount and the server message', () {
      final r = CouponResult.fromJson({
        'valid': true,
        'discount': 250,
        'message': 'Coupon applied! You save ₹250',
      });
      expect(r.valid, isTrue);
      expect(r.discount, 250);
      expect(r.message, contains('250'));
    });
  });
}
