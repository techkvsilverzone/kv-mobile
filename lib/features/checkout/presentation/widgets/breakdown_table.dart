import 'package:flutter/material.dart';
import '../../data/models/checkout_breakdown.dart';
import 'price_details.dart';

/// Renders the server's authoritative totals.
///
/// Order of operations matches the server: subtotal → coupon → GST on the
/// discounted taxable base → delivery last.
class BreakdownTable extends StatelessWidget {
  const BreakdownTable({super.key, required this.breakdown});

  final CheckoutBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final b = breakdown;
    return PriceDetails(
      lines: [
        PriceLine.amount('Subtotal (before GST)', b.subtotal),
        if (b.discount > 0)
          PriceLine.amount(b.couponCode == null ? 'Coupon discount' : 'Coupon (${b.couponCode})', b.discount,
              discount: true),
        PriceLine.amount('GST (${percentLabel(b.gstPercent)}%)', b.taxAmount),
        PriceLine.amount('Delivery', b.deliveryFee),
        if (b.giftWrapFee > 0) PriceLine.amount('Gift wrap', b.giftWrapFee),
      ],
      totalLabel: 'Total',
      total: b.grandTotal,
      // The zone is resolved from city/state, never the pincode, so a zero fee
      // usually means the address did not match a zone.
      footnote: b.deliveryFee == 0 ? 'No delivery charge was applied for this address.' : null,
    );
  }
}
