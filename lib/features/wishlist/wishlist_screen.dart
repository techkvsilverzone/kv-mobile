import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/ui/kv_ui.dart';
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
    final products = ref.watch(_wishlistProductsProvider);
    final count = products.valueOrNull?.length ?? 0;
    return Scaffold(
      backgroundColor: Kv.surface,
      appBar: AppBar(title: Text(count > 0 ? 'Wishlist ($count)' : 'Wishlist')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(wishlistIdsProvider);
          await ref.read(_wishlistProductsProvider.future).catchError((_) => <Product>[]);
        },
        child: ListView(padding: const EdgeInsets.only(top: 12, bottom: 32), children: [
          products.when(
            loading: () => const ProductGridSkeleton(count: 4),
            error: (_, __) => EmptyState(
              icon: Icons.cloud_off_rounded,
              title: "Couldn't load your wishlist",
              message: 'Check your connection and try again.',
              actionLabel: 'Try again',
              onAction: () => ref.invalidate(wishlistIdsProvider),
            ),
            data: (list) => list.isEmpty
                ? EmptyState(
                    icon: Icons.favorite_border_rounded,
                    title: 'Your wishlist is empty',
                    message: 'Tap the heart on any piece to save it here.',
                    actionLabel: 'Browse the shop',
                    onAction: () => context.go('/shop'),
                  )
                : ProductGrid(products: list),
          ),
        ]),
      ),
    );
  }
}
