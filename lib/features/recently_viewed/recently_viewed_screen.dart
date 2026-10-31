import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/ui/kv_ui.dart';
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
    final ids = ref.watch(recentlyViewedProvider);
    final browse = EmptyState(
      icon: Icons.history_rounded,
      title: 'Nothing viewed yet',
      message: 'Pieces you open will show up here so you can find them again.',
      actionLabel: 'Browse the shop',
      onAction: () => context.go('/shop'),
    );

    final Widget body;
    if (ids.isEmpty) {
      body = browse;
    } else {
      final all = ref.watch(_allProductsProvider);
      final products = [
        for (final id in ids) ...?all.valueOrNull?.where((p) => p.id == id).take(1),
      ];
      body = all.isLoading
          ? const ProductGridSkeleton(count: 4)
          : all.hasError
              ? EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: "Couldn't load these pieces",
                  actionLabel: 'Try again',
                  onAction: () => ref.invalidate(_allProductsProvider),
                )
              : products.isEmpty
                  ? EmptyState(
                      icon: Icons.history_rounded,
                      title: 'No longer available',
                      message: 'The pieces you viewed have been taken down.',
                      actionLabel: 'Browse the shop',
                      onAction: () => context.go('/shop'),
                    )
                  : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(Kv.pad, 0, Kv.pad, 12),
                        child: Text('${products.length} piece${products.length != 1 ? 's' : ''}, newest first',
                            style: const TextStyle(fontSize: 13, color: Kv.muted, fontWeight: FontWeight.w500)),
                      ),
                      ProductGrid(products: products),
                    ]);
    }

    return Scaffold(
      backgroundColor: Kv.surface,
      appBar: AppBar(
        title: const Text('Recently viewed'),
        actions: [
          if (ids.isNotEmpty)
            TextButton(
              onPressed: () {
                ref.read(recentlyViewedProvider.notifier).clear();
                showKvToast(context, 'History cleared');
              },
              child: const Text('Clear'),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_allProductsProvider);
          if (ids.isNotEmpty) await ref.read(_allProductsProvider.future).catchError((_) => <Product>[]);
        },
        child: ListView(padding: const EdgeInsets.only(top: 12, bottom: 32), children: [body]),
      ),
    );
  }
}
