import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../catalog/application/catalog_providers.dart';
import '../catalog/data/models/product.dart';
import '../catalog/presentation/widgets/product_grid.dart';
import 'wishlist.dart';

/// Full products for the wishlisted ids, so cards price live like everywhere else.
final _wishlistProductsProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  final ids = await ref.watch(wishlistIdsProvider.future);
  final products = await Future.wait(ids.map((id) => ref.watch(productProvider(id).future).then<Product?>((p) => p, onError: (_) => null)));
  return products.whereType<Product>().toList();
});

/// `/wishlist` (kv-ui Wishlist.tsx).
class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final products = ref.watch(_wishlistProductsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My Wishlist')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(wishlistIdsProvider),
        child: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            child: Row(children: [
              Icon(Icons.favorite_border, size: 28, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Text('My Wishlist',
                  style: theme.textTheme.headlineLarge
                      ?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
            ]),
          ),
          if (products.isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 64),
              child: Column(children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Loading wishlist...', style: TextStyle(color: muted)),
              ]),
            )
          else if ((products.valueOrNull ?? const []).isNotEmpty)
            ProductGrid(products: products.value!)
          else
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outline),
                borderRadius: BorderRadius.circular(8),
                color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.4),
              ),
              child: Column(children: [
                Text('Your wishlist is empty', style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.onSurface)),
                const SizedBox(height: 8),
                Text('Save your favorite pieces and find them here anytime.',
                    textAlign: TextAlign.center, style: TextStyle(color: muted)),
                const SizedBox(height: 24),
                FilledButton(onPressed: () => context.push('/shop'), child: const Text('Browse Collection')),
              ]),
            ),
        ]),
      ),
    );
  }
}
