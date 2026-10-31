import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/format/currency.dart';
import '../cart/application/cart_controller.dart';
import '../savings/application/installment_payer.dart' show showToast;

class GiftVoucher {
  const GiftVoucher({required this.id, required this.name, required this.price, this.description = '', this.tag});
  final String id, name, description;
  final double price;
  final String? tag;
}

/// `GET /gift-vouchers` (`{status, data}` or a bare list), normalised, active
/// only, by sortOrder (kv-ui services/giftVoucher.ts).
List<GiftVoucher> parseGiftVouchers(dynamic raw) {
  final list = raw is List ? raw : (raw is Map && raw['data'] is List ? raw['data'] as List : const []);
  final rows = <(int, GiftVoucher)>[];
  for (final v in list.whereType<Map>()) {
    final price = ((v['amount'] ?? v['value'] ?? v['price'] ?? 0) as num).toDouble();
    final id = (v['id'] ?? v['_id'] ?? '').toString();
    if (v['isActive'] == false || id.isEmpty) continue;
    rows.add((
      (v['sortOrder'] as num?)?.toInt() ?? 0,
      GiftVoucher(
        id: id,
        name: (v['label'] ?? v['name'] ?? '${formatInr(price)} Gift Voucher').toString(),
        price: price,
        description: (v['description'] ?? '').toString(),
        tag: v['tag']?.toString(),
      ),
    ));
  }
  // Stable by sortOrder, like the web's Array.sort.
  final indexed = rows.indexed.toList()
    ..sort((a, b) => a.$2.$1 != b.$2.$1 ? a.$2.$1.compareTo(b.$2.$1) : a.$1.compareTo(b.$1));
  return [for (final (_, (_, v)) in indexed) v];
}

final giftVouchersProvider =
    FutureProvider<List<GiftVoucher>>((ref) async => parseGiftVouchers(await ref.watch(apiClientProvider).get('/gift-vouchers')));

/// Tailwind gradient pairs the web rotates through (amber, primary, rose, violet).
List<Color> _gradient(int i, Color primary) => switch (i % 4) {
      0 => const [Color(0xFFFBBF24), Color(0xFFFDE047)],
      1 => [primary.withValues(alpha: 0.8), primary.withValues(alpha: 0.4)],
      2 => const [Color(0xFFFB7185), Color(0xFFF9A8D4)],
      _ => const [Color(0xFF8B5CF6), Color(0xFFC084FC)],
    };

/// `/gift-vouchers` (kv-ui GiftVouchers.tsx).
class GiftVouchersScreen extends ConsumerStatefulWidget {
  const GiftVouchersScreen({super.key});

  @override
  ConsumerState<GiftVouchersScreen> createState() => _GiftVouchersScreenState();
}

class _GiftVouchersScreenState extends ConsumerState<GiftVouchersScreen> {
  String? _added;

  void _add(GiftVoucher v) {
    ref.read(cartProvider.notifier).addVoucher(id: v.id, name: v.name, price: v.price);
    setState(() => _added = v.id);
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted && _added == v.id) setState(() => _added = null);
    });
    showToast(context, 'Added to cart', '${v.name} added to your cart.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final vouchers = ref.watch(giftVouchersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gift Vouchers')),
      body: ListView(children: [
        Container(
          color: scheme.primary,
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(color: scheme.tertiary, borderRadius: BorderRadius.circular(999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.card_giftcard, size: 16, color: scheme.onTertiary),
                const SizedBox(width: 8),
                Text('Gift Vouchers', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: scheme.onTertiary)),
              ]),
            ),
            const SizedBox(height: 24),
            Text('The Perfect Silver Gift',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w700, color: scheme.onPrimary)),
            const SizedBox(height: 16),
            Text(
                'Give the gift of choice. Our digital and physical gift vouchers are redeemable on our entire silver collection.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: scheme.onPrimary.withValues(alpha: 0.8))),
          ]),
        ),
        Container(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: scheme.outline))),
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, c) => Wrap(runSpacing: 16, children: [
              for (final (icon, label, desc) in const [
                (Icons.card_giftcard, 'Instant Digital Delivery', 'Receive your voucher code via email within minutes.'),
                (Icons.verified_user_outlined, 'Never Expires Early', 'Valid for 12 months from the date of purchase.'),
                (Icons.local_shipping_outlined, 'Physical Cards Available', 'Order a beautifully printed card for in-store gifting.'),
                (Icons.star_border, 'GST Inclusive', 'No hidden taxes — the price shown is the price you pay.'),
              ])
                SizedBox(
                  width: c.maxWidth / 2,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    CircleAvatar(
                        radius: 18,
                        backgroundColor: scheme.tertiary.withValues(alpha: 0.1),
                        child: Icon(icon, size: 16, color: scheme.primary)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        Text(desc, style: TextStyle(fontSize: 12, color: muted)),
                      ]),
                    ),
                  ]),
                ),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 48),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Choose a Voucher',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface)),
            const SizedBox(height: 32),
            if (vouchers.isLoading)
              const Center(child: CircularProgressIndicator())
            else if ((vouchers.valueOrNull ?? const []).isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Text('Gift vouchers are currently unavailable. Please check back soon.',
                    textAlign: TextAlign.center, style: TextStyle(color: muted)),
              )
            else
              for (final (i, v) in vouchers.value!.indexed) ...[
                Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Container(
                      height: 144,
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                              begin: Alignment.topLeft, end: Alignment.bottomRight, colors: _gradient(i, scheme.primary))),
                      child: Stack(children: [
                        Center(child: Icon(Icons.card_giftcard, size: 56, color: Colors.white.withValues(alpha: 0.7))),
                        if (v.tag != null)
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                              child: Text(v.tag!, style: const TextStyle(fontSize: 12, color: Color(0xFF1F2937))),
                            ),
                          ),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Text(v.name,
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface)),
                        const SizedBox(height: 4),
                        Text(v.description, style: TextStyle(fontSize: 14, color: muted, height: 1.5)),
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(formatInr(v.price),
                                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: scheme.primary)),
                              Text('GST incl.', style: TextStyle(fontSize: 12, color: muted)),
                            ]),
                          ),
                          FilledButton(
                            onPressed: _added == v.id ? null : () => _add(v),
                            child: Text(_added == v.id ? 'Added!' : 'Add to Cart'),
                          ),
                        ]),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 24),
              ],
          ]),
        ),
        Container(
          color: scheme.surfaceContainerHigh.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          child: Text(
            'Gift vouchers are valid for 12 months from purchase. They can be redeemed in-store or online. '
            'Not redeemable for cash. Lost or stolen vouchers cannot be replaced.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: muted),
          ),
        ),
      ]),
    );
  }
}
