import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/format/currency.dart';
import '../../../core/widgets/links.dart';
import '../../catalog/data/models/product.dart';
import '../../catalog/presentation/widgets/product_image.dart';
import '../../savings/application/installment_payer.dart';
import '../data/models/order.dart';
import '../data/order_repository.dart';

/// kv-ui pages/OrderConfirmation.tsx, shown after a successful payment.
/// Sections that need the order are hidden when it cannot be loaded, as on
/// the web.
class OrderConfirmationScreen extends ConsumerWidget {
  const OrderConfirmationScreen({super.key, required this.orderId});

  final String orderId;

  static const _steps = [
    ('01', Icons.inventory_2_outlined, 'Hallmarking & Packing',
        'Our artisans verify purity, apply BIS hallmarks, and pack your pieces in our signature gift box.'),
    ('02', Icons.shopping_bag_outlined, 'Insured Dispatch',
        'Your order is fully insured and dispatched via our trusted courier within 24–48 hours.'),
    ('03', Icons.check_circle_outline, 'Delivered to You',
        "Expect delivery within 5–7 business days. You'll receive tracking details via SMS & email."),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(orderProvider(orderId));
    if (async.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final order = async.valueOrNull;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    const green = Color(0xFF22C55E);
    final serif = theme.textTheme.headlineLarge?.copyWith(
        color: scheme.primary, fontWeight: FontWeight.w400, height: 1.2);

    return Scaffold(
      appBar: AppBar(title: const Text('Order Confirmed')),
      body: ListView(
        children: [
          // Celebration header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primary.withValues(alpha: 0.05),
                  scheme.surface,
                  scheme.tertiary.withValues(alpha: 0.1),
                ],
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFBBF7D0), width: 2),
                  ),
                  child: const Icon(Icons.check_circle_outline, size: 48, color: green),
                ),
                const SizedBox(height: 32),
                Text('ORDER CONFIRMED',
                    style: theme.textTheme.labelSmall?.copyWith(color: muted, letterSpacing: 3.6)),
                const SizedBox(height: 12),
                Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'Thank you for your\n'),
                    TextSpan(
                        text: 'precious order', style: serif?.copyWith(fontStyle: FontStyle.italic)),
                  ]),
                  textAlign: TextAlign.center,
                  style: serif,
                ),
                const SizedBox(height: 16),
                Text('Your silver treasures are being carefully prepared.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(color: muted, fontWeight: FontWeight.w300)),
                if (order != null) ...[
                  const SizedBox(height: 8),
                  Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: 'Order '),
                      TextSpan(
                        text: '#${_shortId(order.id)}',
                        style: TextStyle(fontWeight: FontWeight.w500, color: scheme.onSurface),
                      ),
                      if (order.createdAt != null)
                        TextSpan(
                            text: ' • ${DateFormat('d MMMM y').format(order.createdAt!.toLocal())}'),
                    ]),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // What happens next
                Text('What happens next',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(color: scheme.primary)),
                const SizedBox(height: 32),
                for (final (step, icon, title, desc) in _steps)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: Column(
                      children: [
                        Text(step,
                            style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 10, letterSpacing: 2, color: muted.withValues(alpha: 0.5))),
                        const SizedBox(height: 4),
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: scheme.outline),
                            color: scheme.secondaryContainer.withValues(alpha: 0.5),
                          ),
                          child: Icon(icon, size: 28, color: muted),
                        ),
                        const SizedBox(height: 16),
                        Text(title,
                            style: theme.textTheme.titleMedium?.copyWith(
                                fontFamily: theme.textTheme.titleLarge?.fontFamily,
                                color: scheme.primary)),
                        const SizedBox(height: 8),
                        Text(desc,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: muted, fontWeight: FontWeight.w300, height: 1.6)),
                      ],
                    ),
                  ),
                if (order != null) ...[
                  _Summary(order: order),
                  const SizedBox(height: 32),
                  _ResendLine(orderId: order.id),
                  const SizedBox(height: 32),
                ],
                // Authenticity notice
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.05),
                    border: Border.all(color: scheme.primary.withValues(alpha: 0.15)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: scheme.primary.withValues(alpha: 0.1),
                        child: Icon(Icons.check_circle_outline, size: 20, color: scheme.primary),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Certificate of Authenticity Included',
                                style: theme.textTheme.titleMedium?.copyWith(
                                    fontFamily: theme.textTheme.titleLarge?.fontFamily,
                                    color: scheme.primary)),
                            const SizedBox(height: 4),
                            Text(
                              'Your package will include a BIS Hallmark certificate and KV Silver Zone authenticity card. These documents verify the purity and craftsmanship of your silver pieces.',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: muted, fontWeight: FontWeight.w300, height: 1.6),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // CTA row
                if (order != null) ...[
                  OutlinedButton.icon(
                    onPressed: () => context.push('/orders/${order.id}'),
                    icon: const Icon(Icons.inventory_2_outlined, size: 16),
                    label: const Text('Track My Order'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/orders/${order.id}/invoice'),
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Download Invoice'),
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton.icon(
                  onPressed: () => context.go('/shop'),
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('Continue Shopping'),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: muted),
                  onPressed: () => openLink(storePhoneUri),
                  icon: const Icon(Icons.phone_outlined, size: 16),
                  label: const Text('Contact Support'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Web `order.id.slice(-8).toUpperCase()`.
  static String _shortId(String id) =>
      (id.length <= 8 ? id : id.substring(id.length - 8)).toUpperCase();
}

class _Summary extends StatelessWidget {
  const _Summary({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: scheme.secondaryContainer.withValues(alpha: 0.3),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Text('Order Summary',
                style: theme.textTheme.titleLarge?.copyWith(fontSize: 18, color: scheme.primary)),
          ),
          for (final item in order.items) ...[
            Divider(height: 1, color: scheme.outline),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  if (item.image != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: ProductImageView(
                          image: ProductImage(data: item.image!, sortOrder: 0),
                          decodeWidth: 56,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.productName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w500)),
                        Text('Qty: ${item.quantity}',
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Text(formatInr(item.unitPrice * item.quantity),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
          Container(
            color: scheme.secondaryContainer.withValues(alpha: 0.2),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                const Expanded(
                    child: Text('Total Paid', style: TextStyle(fontWeight: FontWeight.w500))),
                Text(formatInr(order.grandTotal),
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w600, color: scheme.primary)),
              ],
            ),
          ),
        ],
      ),
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
      if (mounted) {
        showToast(context, 'Email sent', 'Your order confirmation email has been resent.');
      }
    } on ApiException {
      if (mounted) {
        showToast(context, 'Could not resend', 'Please try again shortly or contact support.',
            error: true);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      children: [
        Text('A confirmation email has been sent to your registered address.',
            textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 13)),
        TextButton(
          onPressed: _sending ? null : _resend,
          child: Text(_sending ? 'Sending…' : 'Resend email'),
        ),
      ],
    );
  }
}
