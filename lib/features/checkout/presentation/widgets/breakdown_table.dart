import 'package:flutter/material.dart';
import '../../../../core/format/currency.dart';
import '../../data/models/checkout_breakdown.dart';

/// Renders the server's authoritative totals.
///
/// Order of operations matches the server: subtotal → coupon → GST on the
/// discounted taxable base → delivery last.
class BreakdownTable extends StatelessWidget {
  const BreakdownTable({super.key, required this.breakdown});

  final CheckoutBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _row(context, 'Subtotal (before GST)', formatInr(breakdown.subtotal)),
            if (breakdown.discount > 0)
              _row(
                context,
                breakdown.couponCode == null
                    ? 'Coupon discount'
                    : 'Coupon (${breakdown.couponCode})',
                '−${formatInr(breakdown.discount)}',
                highlight: true,
              ),
            _row(
              context,
              'GST (${_percent(breakdown.gstPercent)}%)',
              formatInr(breakdown.taxAmount),
            ),
            _row(context, 'Delivery', formatInr(breakdown.deliveryFee)),
            if (breakdown.giftWrapFee > 0) _row(context, 'Gift Wrapping', formatInr(breakdown.giftWrapFee)),
            const Divider(height: 20),
            _row(context, 'Total', formatInr(breakdown.grandTotal), bold: true),
            if (breakdown.deliveryFee == 0) ...[
              const SizedBox(height: 8),
              Text(
                // The zone is resolved from city/state, never the pincode, so a
                // zero fee usually means the address did not match a zone.
                'No delivery charge was applied for this address.',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _percent(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  Widget _row(BuildContext context, String label, String value,
      {bool bold = false, bool highlight = false}) {
    final theme = Theme.of(context);
    final style = bold
        ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)
        : theme.textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(
            value,
            style: highlight
                ? style?.copyWith(color: theme.colorScheme.primary)
                : style,
          ),
        ],
      ),
    );
  }
}
