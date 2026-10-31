import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../catalog/data/catalog_repository.dart';
import '../catalog/data/models/product.dart';
import '../catalog/presentation/widgets/product_grid.dart';
import 'recently_viewed.dart';

/// Every product, fetched only when there is history to resolve (the web
/// fetches the full list and picks the viewed ids out of it).
final _allProductsProvider = FutureProvider.autoDispose<List<Product>>((ref) => ref
    .watch(catalogRepositoryProvider)
    .fetchProducts(const ProductFilters(), page: 1, limit: 1000));

/// `/recently-viewed` (kv-ui RecentlyViewed.tsx).
class RecentlyViewedScreen extends ConsumerWidget {
  const RecentlyViewedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final ids = ref.watch(recentlyViewedProvider);

    Widget header() => Container(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.colorScheme.outline))),
          padding: const EdgeInsets.fromLTRB(16, 40, 16, 40),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.schedule, size: 20, color: muted),
              const SizedBox(width: 12),
              Text('YOUR JOURNEY',
                  style: theme.textTheme.labelSmall?.copyWith(color: muted, letterSpacing: 2.4)),
            ]),
            const SizedBox(height: 16),
            Text('Recently Viewed',
                style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w400)),
            const SizedBox(height: 12),
            Text("Pieces you've admired — revisit them before they're gone.",
                style: TextStyle(color: muted, fontWeight: FontWeight.w300)),
          ]),
        );

    final List<Widget> body;
    if (ids.isEmpty) {
      body = [
        const SizedBox(height: 64),
        Center(
          child: CircleAvatar(
            radius: 40,
            backgroundColor: theme.colorScheme.secondary.withValues(alpha: 0.5),
            child: Icon(Icons.schedule, size: 36, color: muted),
          ),
        ),
        const SizedBox(height: 24),
        Text('Nothing here yet',
            textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text('Browse our collection and this page will remember the pieces that caught your eye.',
            textAlign: TextAlign.center, style: TextStyle(color: muted, fontWeight: FontWeight.w300)),
        const SizedBox(height: 32),
        Center(
          child: FilledButton.icon(
            onPressed: () => context.push('/shop'),
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: const Text('Explore Collection'),
          ),
        ),
      ];
    } else {
      final all = ref.watch(_allProductsProvider);
      final products = [
        for (final id in ids) ...?all.valueOrNull?.where((p) => p.id == id).take(1),
      ];
      body = [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 8, 16),
          child: Row(children: [
            Expanded(
              child: Text('${products.length} piece${products.length != 1 ? 's' : ''} viewed recently',
                  style: TextStyle(fontSize: 14, color: muted)),
            ),
            TextButton.icon(
              onPressed: () => ref.read(recentlyViewedProvider.notifier).clear(),
              style: TextButton.styleFrom(foregroundColor: muted),
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('CLEAR HISTORY', style: TextStyle(fontSize: 12, letterSpacing: 1)),
            ),
          ]),
        ),
        if (all.isLoading)
          const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))
        else if (products.isNotEmpty)
          ProductGrid(products: products)
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Text('Some products may no longer be available.',
                textAlign: TextAlign.center, style: TextStyle(color: muted)),
          ),
        const SizedBox(height: 48),
        Center(
          child: OutlinedButton.icon(
            onPressed: () => context.push('/shop'),
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: const Text('BROWSE FULL COLLECTION',
                style: TextStyle(fontSize: 12, letterSpacing: 2)),
          ),
        ),
      ];
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Recently Viewed')),
      body: ListView(padding: const EdgeInsets.only(bottom: 32), children: [header(), ...body]),
    );
  }
}
