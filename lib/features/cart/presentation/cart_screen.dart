import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/format/currency.dart';
import '../../../core/ui/kv_ui.dart';
import '../../checkout/presentation/widgets/price_details.dart';
import '../application/cart_controller.dart';
import '../application/cart_totals.dart';
import '../data/models/cart_item.dart';
import 'widgets/item_thumb.dart';

/// Cart tab (kv-ui pages/Cart.tsx), including gift wrapping (charged server-side).
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear your cart?'),
        content: const Text('This removes every item from your cart.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
        ],
      ),
    );
    if (ok == true) await ref.read(cartProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(cartRefreshProvider); // re-price lines against the current catalogue
    final items = ref.watch(cartProvider);
    final count = ref.watch(cartCountProvider);
    final hasOutOfStock = ref.watch(cartHasOutOfStockProvider);

    if (items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cart')),
        body: Center(
          child: SingleChildScrollView(
            child: EmptyState(
              icon: Icons.shopping_bag_outlined,
              title: 'Your cart is empty',
              message: 'Browse our silver collection and add your favourites here.',
              actionLabel: 'Start shopping',
              onAction: () => context.go('/shop'),
            ),
          ),
        ),
      );
    }

    final outOfStock = items.where((e) => !e.inStock).length;
    return Scaffold(
      appBar: AppBar(
        title: Text('Cart ($count)'),
        actions: [TextButton(onPressed: () => _confirmClear(context, ref), child: const Text('Clear'))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Kv.pad, 8, Kv.pad, Kv.gap),
        children: [
          if (hasOutOfStock) ...[
            KvCard(
              color: Kv.dangerSoft,
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded, color: Kv.danger, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    outOfStock == 1
                        ? '1 item is out of stock. Remove it to check out.'
                        : '$outOfStock items are out of stock. Remove them to check out.',
                    style: const TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),
          ],
          for (final item in items) ...[
            _CartLine(key: ValueKey(item.lineKey), item: item),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 12),
          const _GiftWrapCard(),
          const SizedBox(height: Kv.gap),
          const _PriceSummary(),
          const SizedBox(height: 16),
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.verified_user_outlined, size: 16, color: Kv.subtle),
            SizedBox(width: 6),
            Text('Insured shipping · BIS hallmarked silver', style: TextStyle(fontSize: 12, color: Kv.subtle)),
          ]),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        leading: BarTotal(label: 'Total', amount: ref.watch(_estimateProvider), note: 'Delivery added at checkout'),
        action: FilledButton(
          onPressed: hasOutOfStock ? null : () => context.push('/checkout'),
          style: FilledButton.styleFrom(minimumSize: const Size(150, 50)),
          child: const Text('Checkout'),
        ),
      ),
    );
  }
}

/// Display-only cart total: subtotal + GST (+ gift wrap). The server prices
/// the charged amount at checkout.
final _estimateProvider = Provider.autoDispose<double>((ref) =>
    ref.watch(cartSubtotalProvider) +
    ref.watch(cartGstProvider) +
    (ref.watch(giftWrapProvider).enabled ? giftWrapFee : 0));

class _CartLine extends ConsumerWidget {
  const _CartLine({super.key, required this.item});

  final CartItem item;

  void _remove(BuildContext context, WidgetRef ref) {
    final controller = ref.read(cartProvider.notifier);
    final index = ref.read(cartProvider).indexWhere((e) => e.lineKey == item.lineKey);
    HapticFeedback.mediumImpact();
    controller.remove(item.lineKey);
    showKvToast(context, 'Removed from cart',
        message: item.name, actionLabel: 'Undo', onAction: () => controller.restore(item, index));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(cartProvider.notifier);
    final details = item.isGiftVoucher
        ? 'GST inclusive'
        : [
            if (item.variantLabel?.isNotEmpty == true) 'Size ${item.variantLabel}',
            item.variantWeight,
            item.purity,
          ].where((s) => s != null && s.isNotEmpty).join(' · ');

    return Dismissible(
      key: ValueKey('dismiss-${item.lineKey}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _remove(context, ref),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(color: Kv.danger, borderRadius: Kv.cardRadius),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.delete_outline_rounded, color: Colors.white),
          SizedBox(width: 6),
          Text('Remove', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ]),
      ),
      child: KvCard(
        color: item.isGiftVoucher ? const Color(0xFFFFFDF8) : null,
        padding: const EdgeInsets.all(12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ItemThumb(image: item.imageData, size: 84, voucher: item.isGiftVoucher),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (item.isGiftVoucher) ...[
                      const StatusPill('Gift voucher', tone: PillTone.gold, icon: Icons.card_giftcard_rounded),
                      const SizedBox(height: 6),
                    ],
                    Text(item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.25)),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(details, style: const TextStyle(fontSize: 13, color: Kv.muted)),
                    ],
                  ]),
                ),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    color: Kv.subtle,
                    tooltip: 'Remove ${item.name} from cart',
                    onPressed: () => _remove(context, ref),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ]),
              if (!item.inStock) ...[
                const SizedBox(height: 6),
                const StatusPill('Out of stock — remove to continue', tone: PillTone.danger),
              ],
              const SizedBox(height: 10),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                QuantityStepper(
                  compact: true,
                  value: item.quantity,
                  // The server rejects an order exceeding stock, so cap here
                  // rather than failing at checkout.
                  max: !item.inStock
                      ? item.quantity
                      : (!item.isGiftVoucher && item.stockAvailable > 0 ? item.stockAvailable : null),
                  onChanged: (q) => controller.setQuantity(item.lineKey, q),
                ),
                const Spacer(),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  if (item.quantity > 1)
                    Text('${formatInr(item.unitPrice)} each', style: const TextStyle(fontSize: 12, color: Kv.subtle)),
                  PriceText(item.lineTotal, size: 16),
                ]),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Gift-box toggle and an optional message (web "Gifting Options").
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
    final wrap = ref.watch(giftWrapProvider);
    void set({bool? enabled, String? message}) => ref.read(giftWrapProvider.notifier).state =
        GiftWrap(enabled: enabled ?? wrap.enabled, message: message ?? wrap.message);

    return KvCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: Kv.goldSoft, shape: BoxShape.circle),
            child: const Icon(Icons.redeem_rounded, color: Kv.gold, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Gift wrap', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              Text('Signature gift box with ribbon · ${formatInr(giftWrapFee)}',
                  style: const TextStyle(fontSize: 12, color: Kv.muted)),
            ]),
          ),
          Switch(value: wrap.enabled, onChanged: (v) => set(enabled: v)),
        ]),
        if (wrap.enabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 6, 0),
            child: TextField(
              controller: _msg,
              maxLength: 200,
              maxLines: 3,
              minLines: 2,
              onChanged: (v) => set(message: v),
              decoration: const InputDecoration(
                labelText: 'Gift message (optional)',
                hintText: 'We’ll print it on a card inside the box',
                alignLabelWithHint: true,
              ),
            ),
          ),
      ]),
    );
  }
}

/// Price details. Display only — the server prices the charged amount at checkout.
class _PriceSummary extends ConsumerWidget {
  const _PriceSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wrap = ref.watch(giftWrapProvider).enabled;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionHeader(title: 'Price details', padding: EdgeInsets.fromLTRB(4, 0, 4, 10)),
      KvCard(
        child: PriceDetails(
          lines: [
            PriceLine.amount('Subtotal (before GST)', ref.watch(cartSubtotalProvider)),
            PriceLine.amount('GST (${percentLabel(ref.watch(cartGstPercentProvider))}%)', ref.watch(cartGstProvider)),
            const PriceLine('Delivery', 'At checkout', muted: true),
            if (wrap) PriceLine.amount('Gift wrap', giftWrapFee),
          ],
          totalLabel: 'Total',
          total: ref.watch(_estimateProvider),
        ),
      ),
    ]);
  }
}
