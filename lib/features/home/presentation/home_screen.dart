import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_session.dart';
import '../../cart/application/cart_controller.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../catalog/data/models/product.dart';
import '../../catalog/presentation/widgets/product_card.dart';
import 'widgets/category_tiles.dart';
import 'widgets/rate_strip.dart';

/// The real Home: hero, live rate strip, category tiles, and featured
/// products. Replaces the placeholder stub. Category tiles and featured
/// products are data-driven; the hero is static copy.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _featuredCount = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final featured = ref.watch(featuredProductsProvider);
    final rates = ref.watch(silverRatesValueProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('KV Silver Zone'),
        actions: [
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
          ref.invalidate(categoriesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _Hero(name: user?.name),
            const SizedBox(height: 16),
            const RateStrip(),
            _SectionHeader(title: 'Shop by category', onSeeAll: () => context.push('/shop')),
            const CategoryTiles(),
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'Featured',
              onSeeAll: () => context.push('/shop'),
            ),
            const SizedBox(height: 8),
            _FeaturedGrid(featured: featured, rates: rates, max: _featuredCount),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.primaryContainer],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name == null ? 'Welcome' : 'Welcome, $name',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.onPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Timeless silver,\neternal elegance',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Handcrafted silver, priced live at today’s rate.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: scheme.onPrimary.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () => context.push('/shop'),
            child: const Text('Explore the collection'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onSeeAll});

  final String title;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          TextButton(onPressed: onSeeAll, child: const Text('See all')),
        ],
      ),
    );
  }
}

class _FeaturedGrid extends StatelessWidget {
  const _FeaturedGrid({required this.featured, required this.rates, required this.max});

  final AsyncValue<List<Product>> featured;
  final List rates;
  final int max;

  @override
  Widget build(BuildContext context) {
    return featured.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      // Featured is a nicety, not load-bearing — a failure just hides the row.
      error: (_, __) => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        final shown = list.take(max).toList();
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 240,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.62,
          ),
          itemCount: shown.length,
          itemBuilder: (context, i) => ProductCard(
            product: shown[i],
            rates: rates.cast(),
            onTap: () => context.push('/product/${shown[i].id}'),
          ),
        );
      },
    );
  }
}
