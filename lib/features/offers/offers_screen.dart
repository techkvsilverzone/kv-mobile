import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/ui/kv_ui.dart';
import '../catalog/application/catalog_providers.dart';
import '../catalog/data/models/product.dart';
import '../catalog/presentation/widgets/product_grid.dart';

class _Campaign {
  const _Campaign(this.title, this.subtitle, this.badge, this.tone, this.icon, this.link, this.linkLabel);
  final String title, subtitle, badge, link, linkLabel;
  final PillTone tone;
  final IconData icon;
}

const _campaigns = [
  _Campaign(
    'Akshaya Tritiya specials',
    'Curated silver gifting for the auspicious day. Zero making charges for a limited time.',
    'Limited time',
    PillTone.gold,
    Icons.auto_awesome_outlined,
    '/shop?category=Puja%20Items',
    'Shop the collection',
  ),
  _Campaign(
    'Silver gifting season',
    'Gift sets from earrings to coin sets, packed in signature KV Silver boxes.',
    'Gift ready',
    PillTone.danger,
    Icons.card_giftcard_outlined,
    '/shop',
    'Explore gift sets',
  ),
  _Campaign(
    'Savings scheme rewards',
    "Join a Gold, Silver or Diwali savings plan and lock in that day's rate on every instalment.",
    'Savings',
    PillTone.success,
    Icons.savings_outlined,
    '/savings-scheme',
    'Start saving',
  ),
];

/// `/offers` (kv-ui Offers.tsx): campaigns, then discounted pieces.
class OffersScreen extends ConsumerWidget {
  const OffersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discounted = ref.watch(discountedProductsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Offers')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(discountedProductsProvider);
          await ref.read(discountedProductsProvider.future).catchError((_) => <Product>[]);
        },
        child: ListView(padding: const EdgeInsets.only(top: Kv.pad, bottom: 32), children: [
          for (final c in _campaigns)
            Padding(padding: const EdgeInsets.fromLTRB(Kv.pad, 0, Kv.pad, 12), child: _CampaignCard(c)),
          // Sale products: shown while loading or when there are any.
          if (discounted.isLoading || (discounted.valueOrNull?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 12),
            SectionHeader(
              title: 'On sale now',
              subtitle: 'Discounted pieces, while stocks last',
              action: 'See all',
              onAction: () => context.go('/shop'),
            ),
            discounted.isLoading ? const ProductGridSkeleton(count: 2) : ProductGrid(products: discounted.value!),
          ],
          const SizedBox(height: Kv.gap),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Kv.pad),
            child: KvCard(
              child: Row(children: [
                for (final (icon, label) in const [
                  (Icons.schedule_rounded, 'Limited period'),
                  (Icons.sell_outlined, 'Real discounts'),
                  (Icons.verified_outlined, 'BIS hallmarked'),
                ])
                  Expanded(
                    child: Column(children: [
                      Icon(icon, size: 22, color: Kv.blue),
                      const SizedBox(height: 6),
                      Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Kv.muted)),
                    ]),
                  ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  const _CampaignCard(this.c);
  final _Campaign c;

  @override
  Widget build(BuildContext context) {
    final (soft, strong) = StatusPill.colors(c.tone);
    return KvCard(
      padding: EdgeInsets.zero,
      onTap: () => context.go(c.link),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            width: 88,
            color: soft,
            alignment: Alignment.center,
            child: Icon(c.icon, size: 34, color: strong),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                StatusPill(c.badge, tone: c.tone),
                const SizedBox(height: 8),
                Text(c.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(c.subtitle, style: const TextStyle(fontSize: 13, color: Kv.muted, height: 1.4)),
                const SizedBox(height: 10),
                Row(children: [
                  Text(c.linkLabel, style: const TextStyle(color: Kv.blue, fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded, size: 16, color: Kv.blue),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
