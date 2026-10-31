import 'package:flutter/material.dart';
import '../../../../core/ui/kv_ui.dart';
import '../../data/models/order.dart';

PillTone orderStatusTone(OrderStatus s) => switch (s) {
      OrderStatus.delivered => PillTone.success,
      OrderStatus.cancelled => PillTone.danger,
      OrderStatus.shipped => PillTone.info,
      OrderStatus.pending || OrderStatus.processing => PillTone.warning,
      OrderStatus.unknown => PillTone.neutral,
    };

class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) => StatusPill(status.label, tone: orderStatusTone(status));
}

/// "24 Oct 2026" (no locale: intl date symbols are not initialised in this app).
String formatOrderDate(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final l = d.toLocal();
  return '${l.day} ${months[l.month - 1]} ${l.year}';
}
