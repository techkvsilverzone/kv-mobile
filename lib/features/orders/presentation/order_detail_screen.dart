import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/format/currency.dart';
import '../data/models/order.dart';
import '../data/order_repository.dart';
import 'widgets/order_status_chip.dart';

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Order')),
      body: order.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off,
                    size: 48, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 16),
                Text(
                  e is ApiException ? e.message : 'Could not load this order.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(orderProvider(orderId)),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (o) => _OrderBody(order: o, onResend: () => _resend(context, ref)),
      ),
    );
  }

  Future<void> _resend(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(orderRepositoryProvider).resendConfirmation(orderId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Confirmation email sent.')),
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

class _OrderBody extends StatelessWidget {
  const _OrderBody({required this.order, required this.onResend});

  final Order order;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(order.invoiceNumber ?? '#${order.shortId}',
                  style: theme.textTheme.titleLarge),
            ),
            OrderStatusChip(status: order.status),
          ],
        ),
        const SizedBox(height: 20),
        if (order.status == OrderStatus.cancelled)
          Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'This order was cancelled. Any payment made will be refunded.',
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
          )
        else
          _StatusTimeline(status: order.status),
        const SizedBox(height: 24),
        Text('Items', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (final item in order.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.productName),
                              Text(
                                'Qty ${item.quantity}'
                                '${item.weight == null ? '' : ' · ${item.weight} g'}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        Text(formatInr(item.totalPrice)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('Payment', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // These are the server's own stored figures. The web's order
                // page back-derives them from a hardcoded 5% GST and claims
                // free shipping, which disagrees with what was charged.
                _row(context, 'Subtotal', formatInr(order.subtotal)),
                if (order.couponDiscount > 0)
                  _row(
                    context,
                    order.couponCode == null
                        ? 'Coupon discount'
                        : 'Coupon (${order.couponCode})',
                    '−${formatInr(order.couponDiscount)}',
                  ),
                _row(context, 'GST', formatInr(order.taxAmount)),
                _row(context, 'Delivery', formatInr(order.deliveryFee)),
                if (order.giftWrapFee > 0) _row(context, 'Gift wrapping', formatInr(order.giftWrapFee)),
                const Divider(height: 20),
                _row(context, 'Total paid', formatInr(order.grandTotal), bold: true),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${order.paymentMethodLabel} · ${order.paymentStatus}',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (order.address != null) ...[
          const SizedBox(height: 24),
          Text('Delivery address', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.address!.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(order.address!.line1),
                  Text('${order.address!.city}, ${order.address!.state} '
                      '${order.address!.pincode}'),
                  const SizedBox(height: 4),
                  Text(order.address!.phone, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        // The web's "Actions" card.
        FilledButton.icon(
          onPressed: () => context.push('/orders/${order.id}/invoice'),
          icon: const Icon(Icons.download, size: 16),
          label: const Text('Download Invoice'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => context.push('/contact'),
          child: const Text('Need Help?'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onResend,
          icon: const Icon(Icons.mail_outline),
          label: const Text('Resend confirmation email'),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value, {bool bold = false}) {
    final theme = Theme.of(context);
    final style = bold
        ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)
        : theme.textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

/// Four-step fulfilment timeline. There are no courier or tracking fields on
/// the order — `deliveredAt` is the only timestamp beyond created/updated — so
/// this reflects status alone and promises nothing more.
class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.status});

  final OrderStatus status;

  static const _steps = [
    (OrderStatus.pending, Icons.receipt_long_outlined),
    (OrderStatus.processing, Icons.inventory_2_outlined),
    (OrderStatus.shipped, Icons.local_shipping_outlined),
    (OrderStatus.delivered, Icons.check_circle_outline),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = status.stepIndex;

    return Row(
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: i <= current ? scheme.primary : scheme.surfaceContainerHighest,
                  child: Icon(
                    _steps[i].$2,
                    size: 18,
                    color: i <= current ? scheme.onPrimary : scheme.outline,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _steps[i].$1.label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: i <= current ? scheme.onSurface : scheme.outline,
                      ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
