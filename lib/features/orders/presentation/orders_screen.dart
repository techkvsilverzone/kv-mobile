import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/format/currency.dart';
import '../data/models/order.dart';
import '../data/order_repository.dart';
import 'widgets/order_status_chip.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(myOrdersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My orders')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myOrdersProvider),
        child: orders.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _Message(
            icon: Icons.cloud_off,
            title: 'Could not load your orders',
            body: e is ApiException ? e.message : 'Please try again.',
            actionLabel: 'Try again',
            onAction: () => ref.invalidate(myOrdersProvider),
          ),
          data: (list) {
            if (list.isEmpty) {
              return _Message(
                icon: Icons.receipt_long_outlined,
                title: 'No orders yet',
                body: 'Your orders will appear here once you place one.',
                actionLabel: 'Browse products',
                onAction: () => context.go('/shop'),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _OrderCard(order: list[i]),
            );
          },
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemCount = order.items.fold<int>(0, (sum, e) => sum + e.quantity);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/orders/${order.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.invoiceNumber ?? '#${order.shortId}',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  OrderStatusChip(status: order.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '$itemCount item${itemCount == 1 ? '' : 's'}'
                '${order.createdAt == null ? '' : ' · ${_formatDate(order.createdAt!)}'}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(order.paymentMethodLabel, style: theme.textTheme.bodySmall),
                  const Spacer(),
                  Text(formatInr(order.grandTotal),
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 80),
        Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 16),
        Text(title,
            textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(body, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Center(child: FilledButton(onPressed: onAction, child: Text(actionLabel))),
      ],
    );
  }
}
