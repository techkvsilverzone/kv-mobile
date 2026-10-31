import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/ui/kv_ui.dart';
import '../../cart/presentation/widgets/item_thumb.dart';
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
        onRefresh: () => ref.refresh(myOrdersProvider.future),
        child: orders.when(
          skipLoadingOnRefresh: true,
          loading: () => ListView(
            padding: const EdgeInsets.only(top: 12),
            children: const [ListSkeleton(rows: 5, height: 112)],
          ),
          error: (e, _) => ListView(children: [
            EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load your orders',
              message: e is ApiException ? e.message : 'Please try again.',
              actionLabel: 'Try again',
              onAction: () => ref.invalidate(myOrdersProvider),
            ),
          ]),
          data: (list) => list.isEmpty
              ? ListView(children: [
                  EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No orders yet',
                    message: 'Your orders will appear here once you place one.',
                    actionLabel: 'Browse products',
                    onAction: () => context.go('/shop'),
                  ),
                ])
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(Kv.pad, 8, Kv.pad, Kv.gap),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _OrderCard(order: list[i]),
                ),
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
    final itemCount = order.items.fold<int>(0, (sum, e) => sum + e.quantity);
    final first = order.items.firstOrNull;
    final names = order.items.map((e) => e.productName).join(', ');

    return KvCard(
      onTap: () => context.push('/orders/${order.id}'),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(order.invoiceNumber ?? 'Order #${order.shortId}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              if (order.createdAt != null)
                Text('Placed ${formatOrderDate(order.createdAt!)}',
                    style: const TextStyle(fontSize: 12, color: Kv.muted)),
            ]),
          ),
          OrderStatusChip(status: order.status),
        ]),
        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
        Row(children: [
          ItemThumb(image: first?.image, size: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(names, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 2),
              Text('$itemCount item${itemCount == 1 ? '' : 's'} · ${order.paymentMethodLabel}',
                  style: const TextStyle(fontSize: 12, color: Kv.muted)),
            ]),
          ),
          const SizedBox(width: 8),
          PriceText(order.grandTotal, size: 15),
          const Icon(Icons.chevron_right, color: Kv.subtle),
        ]),
      ]),
    );
  }
}
