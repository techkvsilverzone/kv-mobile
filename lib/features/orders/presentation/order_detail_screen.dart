import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/ui/kv_ui.dart';
import '../../cart/presentation/widgets/item_thumb.dart';
import '../../checkout/presentation/widgets/price_details.dart';
import '../../returns/request_return_dialog.dart';
import '../data/models/order.dart';
import '../data/order_repository.dart';
import 'widgets/order_status_chip.dart';

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  Future<void> _resend(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(orderRepositoryProvider).resendConfirmation(orderId);
      if (context.mounted) showKvToast(context, 'Confirmation email sent');
    } on ApiException catch (e) {
      if (context.mounted) showKvToast(context, 'Could not resend', message: e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Order details')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(orderProvider(orderId).future),
        child: order.when(
          skipLoadingOnRefresh: true,
          loading: () => ListView(
            padding: const EdgeInsets.only(top: 12),
            children: const [ListSkeleton(rows: 1, height: 90), ListSkeleton(rows: 1, height: 220), ListSkeleton(rows: 2, height: 120)],
          ),
          error: (e, _) => ListView(children: [
            EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load this order',
              message: e is ApiException ? e.message : 'Please try again.',
              actionLabel: 'Try again',
              onAction: () => ref.invalidate(orderProvider(orderId)),
            ),
          ]),
          data: (o) => _OrderBody(order: o, onResend: () => _resend(context, ref)),
        ),
      ),
    );
  }
}

String _grams(double w) => w == w.roundToDouble() ? w.toInt().toString() : w.toString();

class _OrderBody extends StatelessWidget {
  const _OrderBody({required this.order, required this.onResend});

  final Order order;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    Widget section(String title, Widget child) => Padding(
          padding: const EdgeInsets.only(top: Kv.gap),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SectionHeader(title: title, padding: const EdgeInsets.fromLTRB(4, 0, 4, 8)),
            child,
          ]),
        );
    final a = order.address;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Kv.pad, 8, Kv.pad, 32),
      children: [
        KvCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(order.invoiceNumber ?? 'Order #${order.shortId}',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  if (order.createdAt != null)
                    Text('Placed on ${formatOrderDate(order.createdAt!)}',
                        style: const TextStyle(fontSize: 13, color: Kv.muted)),
                ]),
              ),
              OrderStatusChip(status: order.status),
            ]),
            const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Divider()),
            if (order.status == OrderStatus.cancelled)
              const Row(children: [
                Icon(Icons.cancel_outlined, color: Kv.danger, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text('This order was cancelled. Any payment made will be refunded.',
                      style: TextStyle(color: Kv.danger, fontSize: 13)),
                ),
              ])
            else
              _StatusTimeline(order: order),
          ]),
        ),
        section(
          'Items',
          KvCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(children: [
              for (final (i, item) in order.items.indexed) ...[
                if (i > 0) const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(children: [
                    ItemThumb(image: item.image, size: 56),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item.productName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        Text('Qty ${item.quantity}${item.weight == null ? '' : ' · ${_grams(item.weight!)} g'}',
                            style: const TextStyle(fontSize: 12, color: Kv.muted)),
                      ]),
                    ),
                    PriceText(item.totalPrice, size: 14),
                  ]),
                ),
              ],
              if (order.giftWrapFee > 0) ...[
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.redeem_rounded, color: Kv.gold, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(order.giftMessage == null ? 'Gift wrapped' : 'Gift wrapped · “${order.giftMessage}”',
                          style: const TextStyle(fontSize: 13, color: Kv.muted)),
                    ),
                  ]),
                ),
              ],
            ]),
          ),
        ),
        section(
          'Price details',
          KvCard(
            // The server's own stored figures. The web's order page back-derives
            // them from a hardcoded 5% GST and claims free shipping.
            child: PriceDetails(
              lines: [
                PriceLine.amount('Subtotal', order.subtotal),
                if (order.couponDiscount > 0)
                  PriceLine.amount(order.couponCode == null ? 'Coupon discount' : 'Coupon (${order.couponCode})',
                      order.couponDiscount,
                      discount: true),
                PriceLine.amount('GST', order.taxAmount),
                PriceLine.amount('Delivery', order.deliveryFee),
                if (order.giftWrapFee > 0) PriceLine.amount('Gift wrap', order.giftWrapFee),
              ],
              totalLabel: 'Total paid',
              total: order.grandTotal,
            ),
          ),
        ),
        if (a != null)
          section(
            'Delivery address',
            KvCard(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.location_on_outlined, color: Kv.muted, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('${a.line1}\n${a.city}, ${a.state} ${a.pincode}',
                        style: const TextStyle(color: Kv.muted, fontSize: 13, height: 1.4)),
                    if (a.phone.isNotEmpty) Text(a.phone, style: const TextStyle(color: Kv.muted, fontSize: 13)),
                  ]),
                ),
              ]),
            ),
          ),
        section(
          'Payment',
          KvCard(
            child: Row(children: [
              const Icon(Icons.credit_card_rounded, color: Kv.muted, size: 22),
              const SizedBox(width: 12),
              Expanded(child: Text(order.paymentMethodLabel, style: const TextStyle(fontWeight: FontWeight.w500))),
              if (order.paymentStatus.isNotEmpty)
                StatusPill(
                  order.paymentStatus[0].toUpperCase() + order.paymentStatus.substring(1),
                  tone: order.paymentStatus.toLowerCase() == 'paid' ? PillTone.success : PillTone.warning,
                ),
            ]),
          ),
        ),
        const SizedBox(height: Kv.gap),
        MenuGroup(children: [
          MenuRow(
            icon: Icons.download_rounded,
            title: 'Download invoice',
            onTap: () => context.push('/orders/${order.id}/invoice'),
          ),
          if (order.status == OrderStatus.delivered)
            MenuRow(
              icon: Icons.assignment_return_outlined,
              title: 'Request a return',
              subtitle: 'Damaged, wrong item or changed your mind',
              onTap: () => openRequestReturn(context, order),
            ),
          MenuRow(icon: Icons.support_agent_outlined, title: 'Need help?', onTap: () => context.push('/contact')),
          MenuRow(
            icon: Icons.mail_outline_rounded,
            title: 'Resend confirmation email',
            trailing: const SizedBox.shrink(),
            onTap: onResend,
          ),
        ]),
      ],
    );
  }
}

/// Four-step fulfilment stepper. There are no courier or tracking fields on
/// the order — `deliveredAt` is the only timestamp beyond created/updated — so
/// this reflects status alone and promises nothing more.
class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.order});

  final Order order;

  static const _steps = [
    (OrderStatus.pending, 'We’ve received your order'),
    (OrderStatus.processing, 'Hallmarking and packing'),
    (OrderStatus.shipped, 'Insured and on its way'),
    (OrderStatus.delivered, 'Delivered to you'),
  ];

  @override
  Widget build(BuildContext context) {
    final current = order.status.stepIndex;
    String detail(int i) => switch (i) {
          0 when order.createdAt != null => formatOrderDate(order.createdAt!),
          3 when order.deliveredAt != null => formatOrderDate(order.deliveredAt!),
          _ => _steps[i].$2,
        };

    return Column(children: [
      for (var i = 0; i < _steps.length; i++)
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 24,
              child: Column(children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= current ? Kv.blue : Kv.surface,
                    border: Border.all(color: i <= current ? Kv.blue : Kv.line, width: 2),
                  ),
                  child: i <= current ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
                ),
                if (i < _steps.length - 1)
                  Expanded(
                    child: Container(width: 2, color: i < current ? Kv.blue : Kv.line),
                  ),
              ]),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: i < _steps.length - 1 ? 18 : 0, top: 1),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_steps[i].$1.label,
                      style: TextStyle(
                        fontWeight: i == current ? FontWeight.w700 : FontWeight.w500,
                        color: i <= current ? Kv.ink : Kv.subtle,
                      )),
                  Text(detail(i), style: TextStyle(fontSize: 12, color: i <= current ? Kv.muted : Kv.subtle)),
                ]),
              ),
            ),
          ]),
        ),
    ]);
  }
}
