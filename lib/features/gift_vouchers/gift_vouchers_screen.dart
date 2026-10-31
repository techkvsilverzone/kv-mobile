import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/format/currency.dart';
import '../cart/application/cart_controller.dart';
import '../../core/ui/kv_ui.dart';

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

/// Card faces rotate through the brand's dark tones.
List<Color> _gradient(int i) => switch (i % 3) {
      0 => [Kv.ink, Color.lerp(Kv.ink, Kv.blueDark, 0.45)!],
      1 => [Kv.blueDark, Kv.blue],
      _ => [Color.lerp(Kv.gold, Kv.ink, 0.45)!, Kv.gold],
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
    HapticFeedback.mediumImpact();
    ref.read(cartProvider.notifier).addVoucher(id: v.id, name: v.name, price: v.price);
    setState(() => _added = v.id);
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted && _added == v.id) setState(() => _added = null);
    });
    showKvToast(context, 'Added to cart', message: v.name, actionLabel: 'View cart', onAction: () => context.go('/cart'));
  }

  @override
  Widget build(BuildContext context) {
    final vouchers = ref.watch(giftVouchersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gift vouchers')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(giftVouchersProvider);
          await ref.read(giftVouchersProvider.future).catchError((_) => <GiftVoucher>[]);
        },
        child: ListView(padding: const EdgeInsets.fromLTRB(Kv.pad, Kv.pad, Kv.pad, 32), children: [
          const Text('Give the gift of choice',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
          const SizedBox(height: 4),
          const Text('Redeemable on our entire silver collection, online or in store.',
              style: TextStyle(fontSize: 14, color: Kv.muted)),
          const SizedBox(height: 16),
          const _Benefits(),
          const SizedBox(height: Kv.gap),
          ...vouchers.when(
            loading: () => const [ListSkeleton(rows: 2, height: 260)],
            error: (_, __) => [
              EmptyState(
                icon: Icons.cloud_off_rounded,
                title: "Couldn't load vouchers",
                actionLabel: 'Try again',
                onAction: () => ref.invalidate(giftVouchersProvider),
              ),
            ],
            data: (list) => list.isEmpty
                ? const [
                    EmptyState(
                      icon: Icons.card_giftcard_rounded,
                      title: 'No vouchers right now',
                      message: 'Gift vouchers are currently unavailable. Please check back soon.',
                    ),
                  ]
                : [
                    for (final (i, v) in list.indexed) ...[
                      _VoucherTile(voucher: v, colors: _gradient(i), added: _added == v.id, onAdd: () => _add(v)),
                      const SizedBox(height: Kv.gap),
                    ],
                  ],
          ),
          KvCard(
            padding: EdgeInsets.zero,
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: const ExpansionTile(
                leading: Icon(Icons.info_outline_rounded, color: Kv.ink),
                title: Text('Terms', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Text(
                    'Gift vouchers are valid for 12 months from purchase. They can be redeemed in-store or online. '
                    'Not redeemable for cash. Lost or stolen vouchers cannot be replaced.',
                    style: TextStyle(fontSize: 13.5, color: Kv.muted, height: 1.45),
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Benefits extends StatelessWidget {
  const _Benefits();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) => Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (icon, label, desc) in const [
            (Icons.bolt_rounded, 'Instant delivery', 'Code by email in minutes'),
            (Icons.event_available_outlined, 'Valid 12 months', 'From the date of purchase'),
            (Icons.redeem_outlined, 'Printed cards', 'For in-store gifting'),
            (Icons.receipt_long_outlined, 'GST inclusive', 'The price you see is final'),
          ])
            Container(
              width: (c.maxWidth - 8) / 2,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Kv.surface, borderRadius: Kv.smallRadius, border: Border.all(color: Kv.line)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(icon, size: 20, color: Kv.blue),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(desc, style: const TextStyle(fontSize: 11.5, color: Kv.muted, height: 1.3)),
                  ]),
                ),
              ]),
            ),
        ]),
      );
}

/// A voucher drawn as a physical gift card, with its price and add button below.
class _VoucherTile extends StatelessWidget {
  const _VoucherTile({required this.voucher, required this.colors, required this.added, required this.onAdd});
  final GiftVoucher voucher;
  final List<Color> colors;
  final bool added;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final v = voucher;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AspectRatio(
        aspectRatio: 1.62,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
            boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 24, spreadRadius: -6, offset: Offset(0, 10))],
          ),
          child: Stack(children: [
            // Soft "silver sheen" rings.
            Positioned(
              right: -60,
              top: -40,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.10), width: 28)),
              ),
            ),
            Positioned(
              right: 30,
              bottom: -70,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.06)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Image.asset('assets/brand/logo_mark.png', height: 22, width: 22),
                  ),
                  const SizedBox(width: 10),
                  const Text('KV Silver Zone',
                      style: TextStyle(fontFamily: Kv.serif, color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  if (v.tag != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(999)),
                      child: Text(v.tag!,
                          style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                ]),
                const Spacer(),
                Text('GIFT CARD',
                    style: TextStyle(
                        fontSize: 11, letterSpacing: 2, color: Colors.white.withValues(alpha: 0.7), fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(formatInr(v.price),
                    style: const TextStyle(fontSize: 34, color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
              ]),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(v.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            if (v.description.isNotEmpty)
              Text(v.description,
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Kv.muted)),
            Text('${formatInr(v.price)} · GST incl.', style: const TextStyle(fontSize: 12.5, color: Kv.subtle)),
          ]),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: added ? null : onAdd,
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 16)),
          icon: Icon(added ? Icons.check_rounded : Icons.add_shopping_cart_rounded, size: 18),
          label: Text(added ? 'Added' : 'Add to cart'),
        ),
      ]),
    ]);
  }
}
