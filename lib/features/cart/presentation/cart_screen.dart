import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/format/currency.dart';
import '../../catalog/data/models/product.dart';
import '../../catalog/presentation/widgets/product_image.dart';
import '../application/cart_controller.dart';
import '../data/models/cart_item.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(cartProvider);
    final subtotal = ref.watch(cartSubtotalProvider);
    final hasOutOfStock = ref.watch(cartHasOutOfStockProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: items.isEmpty
          ? const _EmptyCart()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _CartLine(item: items[i]),
            ),
      bottomNavigationBar: items.isEmpty
          ? null
          : _CartSummaryBar(
              subtotal: subtotal,
              hasOutOfStock: hasOutOfStock,
              onCheckout: () => context.push('/checkout'),
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
    final controller = ref.read(cartProvider.notifier);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 72,
                height: 72,
                child: ProductImageView(
                  image: item.imageData == null
                      ? null
                      : ProductImage(data: item.imageData!, sortOrder: 0),
                  decodeWidth: 72,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  if (item.variantWeight != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.variantLabel == null || item.variantLabel!.isEmpty
                          ? item.variantWeight!
                          : '${item.variantLabel} · ${item.variantWeight}',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                  if (!item.inStock) ...[
                    const SizedBox(height: 4),
                    Text('Out of stock',
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: theme.colorScheme.error)),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _QuantityStepper(
                        quantity: item.quantity,
                        // The server rejects an order exceeding stock, so cap
                        // here rather than failing at checkout.
                        max: item.stockAvailable > 0 ? item.stockAvailable : 99,
                        onChanged: (q) => controller.setQuantity(item.lineKey, q),
                      ),
                      const Spacer(),
                      Text(formatInr(item.lineTotal),
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Remove',
              onPressed: () => controller.remove(item.lineKey),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.max,
    required this.onChanged,
  });

  final int quantity;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove, size: 18),
            onPressed: () => onChanged(quantity - 1),
          ),
          Text('$quantity'),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add, size: 18),
            onPressed: quantity >= max ? null : () => onChanged(quantity + 1),
          ),
        ],
      ),
    );
  }
}

class _CartSummaryBar extends StatelessWidget {
  const _CartSummaryBar({
    required this.subtotal,
    required this.hasOutOfStock,
    required this.onCheckout,
  });

  final double subtotal;
  final bool hasOutOfStock;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text('Subtotal (before GST)', style: theme.textTheme.bodyMedium),
                const Spacer(),
                Text(formatInr(subtotal), style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'GST and delivery are calculated at checkout.',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: hasOutOfStock ? null : onCheckout,
                child: Text(hasOutOfStock
                    ? 'Remove out-of-stock items to continue'
                    : 'Proceed to checkout'),
              ),
            ),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_bag_outlined,
                size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('Your cart is empty',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('Browse the collection to add something.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/shop'),
              child: const Text('Browse products'),
            ),
          ],
        ),
      ),
    );
  }
}
