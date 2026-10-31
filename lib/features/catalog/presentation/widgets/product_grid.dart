import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../application/catalog_providers.dart';
import '../../data/models/product.dart';
import 'product_card.dart';

/// A non-scrolling grid of product cards for use inside a page's ListView.
class ProductGrid extends ConsumerWidget {
  const ProductGrid({super.key, required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rates = ref.watch(silverRatesValueProvider);
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
      itemCount: products.length,
      itemBuilder: (context, i) => ProductCard(
        product: products[i],
        rates: rates,
        onTap: () => context.push('/product/${products[i].id}'),
      ),
    );
  }
}
