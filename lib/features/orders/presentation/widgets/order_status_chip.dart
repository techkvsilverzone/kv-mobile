import 'package:flutter/material.dart';
import '../../data/models/order.dart';

class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final (bg, fg) = switch (status) {
      OrderStatus.delivered => (scheme.primaryContainer, scheme.onPrimaryContainer),
      OrderStatus.cancelled => (scheme.errorContainer, scheme.onErrorContainer),
      _ => (scheme.secondaryContainer, scheme.onSecondaryContainer),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg),
      ),
    );
  }
}
