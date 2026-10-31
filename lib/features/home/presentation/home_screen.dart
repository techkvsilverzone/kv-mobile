import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../cart/application/cart_controller.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/presentation/widgets/product_grid.dart';
import 'widgets/rate_strip.dart';
import '../../notifications/notifications_screen.dart';

/// kv-ui pages/Index.tsx: hero, trust bar, shop by occasion, featured
/// collection, savings scheme, new arrivals. The web's "Experience Luxury on
/// the Go" app-download block is left out — this is the app.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _shown = 4;

  static const _trustBar = [
    (Icons.workspace_premium_outlined, '100% BIS Hallmarked', 'Certified Silver'),
    (Icons.shield_outlined, 'Insured Shipping', 'Every parcel fully covered'),
    (Icons.restart_alt, 'Fault-Protected Returns', 'Video-verified, 48-hr window'),
    (Icons.headset_mic_outlined, 'Concierge Support', 'Dedicated relationship managers'),
  ];

  /// Web `occasions`: label → the `?category=` it opens.
  static const occasions = [
    ('Coins and Bars', 'Coins', Icons.paid_outlined),
    ('Gifting', 'Silver Articles', Icons.card_giftcard_outlined),
    ('Puja & Ritual', 'Puja Items', Icons.local_fire_department_outlined),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featured = ref.watch(featuredProductsProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;

    Widget products({required bool skeleton}) => featured.when(
          loading: () => skeleton
              ? GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: List.generate(
                    _shown,
                    (_) => DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                )
              : const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                ),
          error: (_, __) => const SizedBox.shrink(),
          data: (list) => ProductGrid(products: list.take(_shown).toList()),
        );

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('KV Silver Zone'),
        actions: [
          if (ref.watch(authSessionProvider).isAuthenticated) const NotificationBell(),
          IconButton(
            icon: const Icon(Icons.favorite_border),
            tooltip: 'Wishlist',
            onPressed: () => context.push('/wishlist'),
          ),
          Consumer(
            builder: (context, ref, _) {
              final count = ref.watch(cartCountProvider);
              return Badge(
                isLabelVisible: count > 0,
                label: Text('$count'),
                child: IconButton(
                  icon: const Icon(Icons.shopping_bag_outlined),
                  tooltip: 'Cart',
                  onPressed: () => context.push('/cart'),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'My profile',
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(featuredProductsProvider);
          ref.invalidate(silverRatesProvider);
          ref.invalidate(goldRatesProvider);
          ref.invalidate(rateHistoryProvider((Metal.silver, 2)));
          ref.invalidate(rateHistoryProvider((Metal.gold, 2)));
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            const _Hero(),
            const SizedBox(height: 16),
            const RateStrip(),
            // Trust bar
            Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(
                  top: BorderSide(color: scheme.outline),
                  bottom: BorderSide(color: scheme.outline),
                ),
              ),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.25,
                children: [
                  for (final (icon, title, body) in _trustBar)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon, size: 28, color: muted),
                          const SizedBox(height: 12),
                          Text(title,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleSmall?.copyWith(
                                  fontFamily: theme.textTheme.titleLarge?.fontFamily,
                                  color: scheme.primary)),
                          const SizedBox(height: 4),
                          Text(body.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(color: muted, fontSize: 10, letterSpacing: 0.8)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // Shop by Occasion
            Container(
              color: scheme.secondaryContainer.withValues(alpha: 0.3),
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                children: [
                  const _SectionTitle(eyebrow: 'Browse by Lifestyle', title: 'Shop by Occasion'),
                  for (final (label, query, icon) in occasions)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Card(
                        margin: EdgeInsets.zero,
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () =>
                              context.push('/shop?category=${Uri.encodeQueryComponent(query)}'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 32,
                                  backgroundColor: scheme.secondaryContainer,
                                  child: Icon(icon, size: 28, color: scheme.primary),
                                ),
                                const SizedBox(height: 16),
                                Text(label.toUpperCase(),
                                    style: theme.textTheme.labelMedium?.copyWith(
                                        color: muted,
                                        letterSpacing: 2,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Featured Collection
            const _SectionTitle(eyebrow: 'Curated Excellence', title: 'Featured Collection'),
            products(skeleton: false),
            const SizedBox(height: 32),
            Center(
              child: OutlinedButton.icon(
                onPressed: () => context.push('/shop'),
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('VIEW ALL MASTERPIECES', style: TextStyle(letterSpacing: 2)),
              ),
            ),
            const SizedBox(height: 32),
            // Savings Scheme
            Container(
              color: scheme.secondaryContainer.withValues(alpha: 0.4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 300,
                    child: Image.asset(
                      'assets/images/savings-scheme.jpg',
                      fit: BoxFit.cover,
                      semanticLabel: 'Savings Scheme',
                      errorBuilder: (_, __, ___) =>
                          ColoredBox(color: scheme.secondaryContainer),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text('INVESTMENT PLAN',
                              style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 10,
                                  letterSpacing: 1,
                                  color: scheme.primary.withValues(alpha: 0.8))),
                        ),
                        const SizedBox(height: 24),
                        Text('Smart Savings,\nSilver Future',
                            style: theme.textTheme.headlineLarge
                                ?.copyWith(color: scheme.primary, height: 1.2)),
                        const SizedBox(height: 24),
                        Text(
                          'Secure your future with our flexible monthly savings scheme. Enjoy bonus months and exclusive benefits on maturity.',
                          style: theme.textTheme.bodyLarge
                              ?.copyWith(color: muted, fontWeight: FontWeight.w300, height: 1.6),
                        ),
                        const SizedBox(height: 24),
                        for (final benefit in const [
                          'Bonus installment on completion',
                          'Zero making charges on redemption',
                          'Locked-in silver rates',
                        ])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: scheme.primary.withValues(alpha: 0.5),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(benefit.toUpperCase(),
                                      style: theme.textTheme.bodySmall?.copyWith(
                                          letterSpacing: 0.6,
                                          color: scheme.primary.withValues(alpha: 0.8))),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => context.push('/savings-scheme'),
                          child: const Text('START INVESTING', style: TextStyle(letterSpacing: 2)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // New Arrivals (the web shows the same featured list again)
            const _SectionTitle(eyebrow: 'Fresh from Atelier', title: 'New Arrivals'),
            products(skeleton: true),
          ],
        ),
      ),
    );
  }
}

/// The home sections' centred eyebrow + serif title + short rule.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.eyebrow, required this.title});

  final String eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 32),
      child: Column(
        children: [
          Text(eyebrow.toUpperCase(),
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant, letterSpacing: 2.4)),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineLarge
                  ?.copyWith(fontWeight: FontWeight.w400, color: theme.colorScheme.primary)),
          const SizedBox(height: 24),
          Container(width: 96, height: 1, color: theme.colorScheme.primary.withValues(alpha: 0.2)),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final serif = theme.textTheme.displaySmall?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w500,
      height: 1.05,
    );

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/banner.jpg',
            fit: BoxFit.cover,
            semanticLabel: 'KV Silver Zone Collection',
            errorBuilder: (_, __, ___) => DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [scheme.primary, scheme.primaryContainer]),
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x80000000), Color(0x66000000), Color(0xB3000000)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('KV SILVER ZONE EXCLUSIVE',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        letterSpacing: 4,
                        fontWeight: FontWeight.w300)),
                const SizedBox(height: 24),
                Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'Timeless Silver,\n'),
                    TextSpan(
                        text: 'Eternal Elegance', style: serif?.copyWith(fontStyle: FontStyle.italic)),
                  ]),
                  textAlign: TextAlign.center,
                  style: serif,
                ),
                const SizedBox(height: 32),
                Text(
                  'Discover our exquisite collection of handcrafted silver jewellery. Designed to define luxury and celebrate tradition.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w300,
                      height: 1.6),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: 220,
                  height: 48,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.white, foregroundColor: Colors.black),
                    onPressed: () => context.push('/shop'),
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('EXPLORE COLLECTION', style: TextStyle(letterSpacing: 1.2)),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 220,
                  height: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
                    ),
                    onPressed: () => context.push('/savings-scheme'),
                    child: const Text('SAVINGS SCHEME', style: TextStyle(letterSpacing: 1.2)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
