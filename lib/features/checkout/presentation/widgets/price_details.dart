import 'package:flutter/material.dart';
import '../../../../core/format/currency.dart';
import '../../../../core/ui/kv_ui.dart';

/// One row of [PriceDetails]. [value] is text so a row can say "At checkout".
class PriceLine {
  const PriceLine(this.label, this.value, {this.discount = false, this.muted = false});
  PriceLine.amount(this.label, double amount, {this.discount = false})
      : value = discount ? '−${formatInr(amount)}' : formatInr(amount),
        muted = false;

  final String label;
  final String value;
  final bool discount;
  final bool muted;
}

/// "Price details" rows and a bold total, used by cart, checkout and orders.
class PriceDetails extends StatelessWidget {
  const PriceDetails({super.key, required this.lines, required this.totalLabel, required this.total, this.footnote});

  final List<PriceLine> lines;
  final String totalLabel;
  final double total;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final l in lines)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Expanded(child: Text(l.label, style: const TextStyle(color: Kv.muted, fontSize: 14))),
            Text(l.value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: l.discount ? FontWeight.w600 : FontWeight.w500,
                  color: l.discount ? Kv.success : (l.muted ? Kv.subtle : Kv.ink),
                )),
          ]),
        ),
      const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
      Row(children: [
        Expanded(child: Text(totalLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
        PriceText(total, size: 18),
      ]),
      if (footnote != null) ...[
        const SizedBox(height: 8),
        Text(footnote!, style: const TextStyle(fontSize: 12, color: Kv.subtle)),
      ],
    ]);
  }
}

/// `3` not `3.0`, as JS prints it.
String percentLabel(double p) => p == p.roundToDouble() ? p.toInt().toString() : p.toString();
