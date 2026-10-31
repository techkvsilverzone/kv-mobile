import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../catalog/application/catalog_providers.dart';
import '../catalog/presentation/widgets/product_grid.dart';

class _Campaign {
  const _Campaign(this.title, this.subtitle, this.badge, this.gradient, this.accent, this.icon,
      this.link, this.linkLabel);
  final String title, subtitle, badge, link, linkLabel;
  final List<Color> gradient; // Tailwind *-50 pair, as on the web
  final (Color bg, Color border, Color text) accent; // *-100 / *-200 / *-700
  final IconData icon;
}

const _campaigns = [
  _Campaign(
    'Akshaya Tritiya Specials',
    'Celebrate the auspicious day with our curated silver gifting collection. Zero making charges for a limited time.',
    'Limited Time',
    [Color(0xFFFFFBEB), Color(0xFFFFF7ED)],
    (Color(0xFFFEF3C7), Color(0xFFFDE68A), Color(0xFFB45309)),
    Icons.auto_awesome,
    '/shop?category=Puja%20Items',
    'Shop Auspicious Collection',
  ),
  _Campaign(
    'Silver Gifting Season',
    'Thoughtfully curated gift sets — from earrings to coin sets — elegantly packed in signature KV Silver boxes.',
    'Gift Ready',
    [Color(0xFFFFF1F2), Color(0xFFFDF2F8)],
    (Color(0xFFFFE4E6), Color(0xFFFECDD3), Color(0xFFBE123C)),
    Icons.card_giftcard,
    '/shop',
    'Explore Gift Sets',
  ),
  _Campaign(
    'Savings Scheme Rewards',
    "Enroll in our Gold Purchase Plan, Silver Purchase Plan, or Diwali savings scheme and lock in today's rates on every installment.",
    'Investment',
    [Color(0xFFF0FDFA), Color(0xFFECFEFF)],
    (Color(0xFFCCFBF1), Color(0xFF99F6E4), Color(0xFF0F766E)),
    Icons.percent,
    '/savings-scheme',
    'Start Saving Today',
  ),
];

/// `/offers` (kv-ui Offers.tsx): campaign cards, discounted pieces, trust strip.
class OffersScreen extends ConsumerWidget {
  const OffersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final discounted = ref.watch(discountedProductsProvider);
    final serif = theme.textTheme.headlineSmall;

    return Scaffold(
      appBar: AppBar(title: const Text('Offers')),
      body: ListView(
        children: [
          // Hero
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: scheme.outline)),
              gradient: RadialGradient(
                center: Alignment.topRight,
                radius: 1.2,
                colors: [scheme.primary.withValues(alpha: 0.08), Colors.transparent],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 48),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.sell_outlined, size: 12, color: scheme.primary.withValues(alpha: 0.7)),
                  const SizedBox(width: 8),
                  Text('EXCLUSIVE OFFERS',
                      style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 2,
                          color: scheme.primary.withValues(alpha: 0.7))),
                ]),
              ),
              const SizedBox(height: 24),
              Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Deals &\n'),
                  TextSpan(text: 'Campaigns', style: const TextStyle(fontStyle: FontStyle.italic)),
                ]),
                style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w400, height: 1.15),
              ),
              const SizedBox(height: 16),
              Text('Curated promotions on our finest silver collections. Limited periods, timeless pieces.',
                  style: TextStyle(fontSize: 18, color: muted, fontWeight: FontWeight.w300, height: 1.5)),
            ]),
          ),
          // Campaigns
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Active Campaigns', style: serif),
              const SizedBox(height: 24),
              for (final c in _campaigns) ...[_CampaignCard(c), const SizedBox(height: 16)],
            ]),
          ),
          // Sale products: shown while loading or when there are any
          if (discounted.isLoading || (discounted.valueOrNull?.isNotEmpty ?? false)) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 8, 24),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('ON SALE NOW',
                        style: TextStyle(fontSize: 12, letterSpacing: 2.4, color: muted)),
                    const SizedBox(height: 8),
                    Text('Discounted Pieces',
                        style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w400)),
                  ]),
                ),
                TextButton.icon(
                  onPressed: () => context.push('/shop'),
                  style: TextButton.styleFrom(foregroundColor: muted),
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.arrow_forward, size: 14),
                  label: const Text('VIEW ALL', style: TextStyle(fontSize: 12, letterSpacing: 1)),
                ),
              ]),
            ),
            discounted.isLoading
                ? const Padding(
                    padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))
                : ProductGrid(products: discounted.value!),
            const SizedBox(height: 40),
          ],
          // Trust strip
          Container(
            decoration: BoxDecoration(
              color: scheme.secondary.withValues(alpha: 0.3),
              border: Border(top: BorderSide(color: scheme.outline)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
            child: Column(children: [
              for (final (icon, label, desc) in const [
                (Icons.schedule, 'Limited Period', 'All offers are time-sensitive'),
                (Icons.sell_outlined, 'Genuine Discounts', 'No hidden markups, real savings'),
                (Icons.auto_awesome, 'BIS Hallmarked', 'Purity guaranteed on all pieces'),
              ]) ...[
                Icon(icon, size: 20, color: muted),
                const SizedBox(height: 8),
                Text(label,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontFamily: 'PlayfairDisplay', color: scheme.primary)),
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(fontSize: 12, color: muted)),
                const SizedBox(height: 24),
              ],
            ]),
          ),
        ],
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  const _CampaignCard(this.c);
  final _Campaign c;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (badgeBg, badgeBorder, badgeText) = c.accent;
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline),
        gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight, colors: c.gradient),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: badgeBg,
            border: Border.all(color: badgeBorder),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(c.icon, size: 12, color: badgeText),
            const SizedBox(width: 6),
            Text(c.badge.toUpperCase(),
                style: TextStyle(
                    fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w500, color: badgeText)),
          ]),
        ),
        const SizedBox(height: 24),
        Text(c.title,
            style: theme.textTheme.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.w500)),
        const SizedBox(height: 12),
        Text(c.subtitle,
            style: TextStyle(
                fontSize: 14, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w300, height: 1.6)),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => context.push(c.link),
            style: OutlinedButton.styleFrom(
                side: BorderSide(color: scheme.primary.withValues(alpha: 0.2)),
                foregroundColor: scheme.primary),
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_forward, size: 14),
            label: Text(c.linkLabel.toUpperCase(),
                style: const TextStyle(fontSize: 12, letterSpacing: 1)),
          ),
        ),
      ]),
    );
  }
}
