import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/ui/kv_ui.dart';
import '../../application/catalog_providers.dart';
import '../../data/models/product.dart';
import 'product_card.dart';

/// Two-column product grid for use inside a scrolling page.
class ProductGrid extends ConsumerWidget {
  const ProductGrid({super.key, required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rates = ref.watch(silverRatesValueProvider);
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 600 ? 3 : 2;
    final cell = (width - Kv.pad * 2 - 12 * (columns - 1)) / columns;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: Kv.pad),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 20,
        crossAxisSpacing: 12,
        mainAxisExtent: cell + productCardInfoHeight,
      ),
      itemCount: products.length,
      itemBuilder: (context, i) => ProductCard(
        product: products[i],
        rates: rates,
        onTap: () => context.push('/product/${products[i].id}'),
      ),
    );
  }
}

/// Horizontal scroller of product cards (Home rows, "related").
class ProductCarousel extends ConsumerWidget {
  const ProductCarousel({super.key, required this.products, this.cardWidth = 164});

  final List<Product> products;
  final double cardWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rates = ref.watch(silverRatesValueProvider);
    return SizedBox(
      height: cardWidth + productCardInfoHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Kv.pad),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) => SizedBox(
          width: cardWidth,
          child: ProductCard(
            product: products[i],
            rates: rates,
            onTap: () => context.push('/product/${products[i].id}'),
          ),
        ),
      ),
    );
  }
}
