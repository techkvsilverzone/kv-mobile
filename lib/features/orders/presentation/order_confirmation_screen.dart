import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/ui/kv_ui.dart';
import '../../../core/widgets/links.dart';
import '../../cart/presentation/widgets/item_thumb.dart';
import '../data/models/order.dart';
import '../data/order_repository.dart';

/// kv-ui pages/OrderConfirmation.tsx, shown after a successful payment.
/// Sections that need the order are hidden when it cannot be loaded, as on
/// the web.
class OrderConfirmationScreen extends ConsumerWidget {
  const OrderConfirmationScreen({super.key, required this.orderId});

  final String orderId;

  static const _steps = [
    (Icons.verified_outlined, 'Hallmarking & packing', 'Purity checked, BIS hallmarked and packed in our gift box.'),
    (Icons.local_shipping_outlined, 'Insured dispatch', 'Shipped fully insured within 24–48 hours.'),
    (Icons.home_outlined, 'Delivered to you', 'In 5–7 business days. Tracking comes by SMS and email.'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(orderProvider(orderId));
    final order = async.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [IconButton(tooltip: 'Close', onPressed: () => context.go('/home'), icon: const Icon(Icons.close))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Kv.pad, 8, Kv.pad, Kv.gap),
        children: [
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Kv.successSoft,
                border: Border.all(color: Kv.success.withValues(alpha: 0.18), width: 8),
              ),
              child: const Icon(Icons.check_rounded, size: 48, color: Kv.success),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Order confirmed',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
          const SizedBox(height: 6),
          const Text('Thank you! Your silver is being carefully prepared.',
              textAlign: TextAlign.center, style: TextStyle(color: Kv.muted, fontSize: 15)),
          if (order != null) ...[
            const SizedBox(height: 12),
            Center(
              child: StatusPill(
                'Order #${_shortId(order.id)}'
                '${order.createdAt == null ? '' : ' · ${DateFormat('d MMMM y').format(order.createdAt!.toLocal())}'}',
                tone: PillTone.neutral,
              ),
            ),
          ],
          const SizedBox(height: 28),
          if (async.isLoading)
            const ListSkeleton(rows: 2, height: 96)
          else if (order != null) ...[
            _Summary(order: order),
            const SizedBox(height: 12),
            _ResendLine(orderId: order.id),
            const SizedBox(height: 12),
          ],
          const SectionHeader(title: 'What happens next', padding: EdgeInsets.fromLTRB(4, 0, 4, 10)),
          KvCard(
            child: Column(children: [
              for (final (i, (icon, title, desc)) in _steps.indexed) ...[
                if (i > 0) const SizedBox(height: 16),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(color: Kv.blueSoft, shape: BoxShape.circle),
                    child: Icon(icon, size: 20, color: Kv.blue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(desc, style: const TextStyle(fontSize: 13, color: Kv.muted, height: 1.35)),
                    ]),
                  ),
                ]),
              ],
            ]),
          ),
          const SizedBox(height: 12),
          const KvCard(
            color: Kv.goldSoft,
            padding: EdgeInsets.all(14),
            child: Row(children: [
              Icon(Icons.workspace_premium_outlined, color: Kv.gold),
              SizedBox(width: 12),
              Expanded(
                child: Text('Your parcel includes a BIS hallmark certificate and a KV authenticity card.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B5320))),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Kv.muted),
              onPressed: () => openLink(storePhoneUri),
              icon: const Icon(Icons.phone_outlined, size: 16),
              label: const Text('Contact support'),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        action: Row(children: [
          if (order != null) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: () => context.push('/orders/${order.id}'),
                child: const Text('View order'),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: FilledButton(onPressed: () => context.go('/shop'), child: const Text('Keep shopping')),
          ),
        ]),
      ),
    );
  }

  /// Web `order.id.slice(-8).toUpperCase()`.
  static String _shortId(String id) => (id.length <= 8 ? id : id.substring(id.length - 8)).toUpperCase();
}

class _Summary extends StatelessWidget {
  const _Summary({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return KvCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(children: [
        for (final item in order.items) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              ItemThumb(image: item.image, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text('Qty: ${item.quantity}', style: const TextStyle(fontSize: 12, color: Kv.muted)),
                ]),
              ),
              PriceText(item.unitPrice * item.quantity, size: 14),
            ]),
          ),
          const Divider(),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            const Expanded(child: Text('Total paid', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
            PriceText(order.grandTotal, size: 18),
          ]),
        ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: const Icon(Icons.download_rounded, color: Kv.ink),
          title: const Text('Download invoice', style: TextStyle(fontSize: 14)),
          trailing: const Icon(Icons.chevron_right, color: Kv.subtle),
          onTap: () => context.push('/orders/${order.id}/invoice'),
        ),
      ]),
    );
  }
}

class _ResendLine extends ConsumerStatefulWidget {
  const _ResendLine({required this.orderId});

  final String orderId;

  @override
  ConsumerState<_ResendLine> createState() => _ResendLineState();
}

class _ResendLineState extends ConsumerState<_ResendLine> {
  bool _sending = false;

  Future<void> _resend() async {
    setState(() => _sending = true);
    try {
      await ref.read(orderRepositoryProvider).resendConfirmation(widget.orderId);
      if (mounted) showKvToast(context, 'Email sent', message: 'Your order confirmation email has been resent.');
    } on ApiException {
      if (mounted) {
        showKvToast(context, 'Could not resend', message: 'Please try again shortly or contact support.', error: true);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.mail_outline_rounded, size: 16, color: Kv.muted),
        const SizedBox(width: 6),
        const Flexible(
          child: Text('Confirmation sent to your email.', style: TextStyle(color: Kv.muted, fontSize: 13)),
        ),
        TextButton(
          onPressed: _sending ? null : _resend,
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          child: Text(_sending ? 'Sending…' : 'Resend email'),
        ),
      ]);
}
