import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/format/currency.dart';
import '../../catalog/data/models/product.dart';
import '../../catalog/presentation/widgets/product_image.dart';
import '../application/cart_controller.dart';
import '../application/cart_totals.dart';
import '../data/models/cart_item.dart';

/// kv-ui pages/Cart.tsx, including gift wrapping (now charged server-side).
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(cartProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: items.isEmpty
          ? const _EmptyCart()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Shopping Cart',
                    style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 24),
                for (final item in items) ...[
                  _CartLine(item: item),
                  const SizedBox(height: 16),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: () => ref.read(cartProvider.notifier).clear(),
                    child: const Text('Clear Cart'),
                  ),
                ),
                const SizedBox(height: 24),
                const _GiftWrapCard(),
                const SizedBox(height: 16),
                const _OrderSummary(),
              ],
            ),
    );
  }
}

class _CartLine extends ConsumerWidget {
  const _CartLine({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final controller = ref.read(cartProvider.notifier);
    final details = [item.variantWeight, item.purity]
        .where((s) => s != null && s.isNotEmpty)
        .join(' • ');

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 96,
                height: 96,
                child: ProductImageView(
                  image: item.imageData == null
                      ? null
                      : ProductImage(data: item.imageData!, sortOrder: 0),
                  decodeWidth: 96,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                    fontFamily: theme.textTheme.titleLarge?.fontFamily,
                                    fontWeight: FontWeight.w600)),
                            if (details.isNotEmpty)
                              Text(details,
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(color: scheme.onSurfaceVariant)),
                            if (!item.inStock)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('Out of stock — remove to continue',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                        color: scheme.error, fontWeight: FontWeight.w500)),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, size: 18, color: scheme.error),
                        tooltip: 'Remove ${item.name} from cart',
                        onPressed: () => controller.remove(item.lineKey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _StepButton(
                        icon: Icons.remove,
                        tooltip: 'Decrease quantity of ${item.name}',
                        onPressed: () => controller.setQuantity(item.lineKey, item.quantity - 1),
                      ),
                      SizedBox(
                        width: 32,
                        child: Text('${item.quantity}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w500)),
                      ),
                      _StepButton(
                        icon: Icons.add,
                        tooltip: 'Increase quantity of ${item.name}',
                        // The server rejects an order exceeding stock, so cap
                        // here rather than failing at checkout.
                        onPressed: !item.isGiftVoucher &&
                                item.stockAvailable > 0 &&
                                item.quantity >= item.stockAvailable
                            ? null
                            : () => controller.setQuantity(item.lineKey, item.quantity + 1),
                      ),
                      const Spacer(),
                      Text(formatInr(item.lineTotal),
                          style: TextStyle(fontWeight: FontWeight.w600, color: scheme.primary)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton.outlined(
        padding: EdgeInsets.zero,
        iconSize: 16,
        tooltip: tooltip,
        icon: Icon(icon),
        onPressed: onPressed,
      ),
    );
  }
}

/// The web's "Gifting Options" card: a gift-box toggle and an optional message.
class _GiftWrapCard extends ConsumerStatefulWidget {
  const _GiftWrapCard();

  @override
  ConsumerState<_GiftWrapCard> createState() => _GiftWrapCardState();
}

class _GiftWrapCardState extends ConsumerState<_GiftWrapCard> {
  late final TextEditingController _msg;

  @override
  void initState() {
    super.initState();
    _msg = TextEditingController(text: ref.read(giftWrapProvider).message);
  }

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final wrap = ref.watch(giftWrapProvider);
    void set({bool? enabled, String? message}) => ref.read(giftWrapProvider.notifier).state =
        GiftWrap(enabled: enabled ?? wrap.enabled, message: message ?? wrap.message);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(Icons.card_giftcard, size: 16, color: muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Gift Wrapping',
                  style: TextStyle(
                      fontFamily: 'PlayfairDisplay', fontWeight: FontWeight.w500, color: theme.colorScheme.primary)),
            ),
            Switch(value: wrap.enabled, onChanged: (v) => set(enabled: v)),
          ]),
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Text('Premium KV Silver gift box with ribbon — ${formatInr(giftWrapFee)}',
                style: TextStyle(fontSize: 12, color: muted)),
          ),
          if (wrap.enabled) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: TextField(
                controller: _msg,
                maxLength: 200,
                maxLines: 3,
                onChanged: (v) => set(message: v),
                decoration: const InputDecoration(
                  labelText: 'Personalized Message',
                  hintText: 'Add a heartfelt message for the recipient… (optional)',
                  alignLabelWithHint: true,
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

/// The web's "Order Summary" card. Display only — the server prices the
/// charged amount at checkout.
class _OrderSummary extends ConsumerWidget {
  const _OrderSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final subtotal = ref.watch(cartSubtotalProvider);
    final gst = ref.watch(cartGstProvider);
    final hasOutOfStock = ref.watch(cartHasOutOfStockProvider);
    final wrap = ref.watch(giftWrapProvider).enabled;

    Widget row(String label, String value, {bool mutedValue = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(child: Text(label, style: TextStyle(color: muted))),
              Text(value, style: mutedValue ? TextStyle(color: muted) : null),
            ],
          ),
        );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Order Summary',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            row('Subtotal (before GST)', formatInr(subtotal)),
            row('GST', formatInr(gst)),
            row('Delivery', 'Calculated at checkout', mutedValue: true),
            if (wrap) row('Gift Wrapping', formatInr(giftWrapFee)),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(child: Text('Total', style: theme.textTheme.titleMedium)),
                Text(formatInr(subtotal + gst + (wrap ? giftWrapFee : 0)),
                    style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
              ],
            ),
            const SizedBox(height: 24),
            if (hasOutOfStock)
              const FilledButton(onPressed: null, child: Text('Remove out-of-stock items'))
            else
              FilledButton.icon(
                onPressed: () => context.push('/checkout'),
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Proceed to Checkout'),
              ),
            if (hasOutOfStock)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text('One or more items are out of stock. Please remove them to proceed.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.error)),
              ),
            const SizedBox(height: 16),
            Text('Insured shipping · GST & delivery calculated at checkout',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(color: muted)),
          ],
        ),
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 96, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 24),
            Text('Your Cart is Empty',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Text("Looks like you haven't added anything to your cart yet.",
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => context.go('/shop'),
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Start Shopping'),
            ),
          ],
        ),
      ),
    );
  }
}
