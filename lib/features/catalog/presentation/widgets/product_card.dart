import 'package:flutter/material.dart';
import '../../../../core/format/currency.dart';
import '../../../../core/pricing/pricing.dart';
import '../../data/models/product.dart';
import 'product_image.dart';

/// Grid tile. Shows the live computed price only — no breakdown and no GST,
/// matching the web's card.
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, required this.rates, required this.onTap});

  final Product product;
  final List<MetalRate> rates;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pricing = computeProductPricing(product.toPricingInput(), rates);

    // Variant weights are a text hint on the card ("20g / 30g"), not a selector.
    final weightHint = product.variants
        .map((v) => v.weight)
        .where((w) => w.isNotEmpty)
        .join(' / ');

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Grid tiles are ~240 logical px at most (see the grid's
                  // maxCrossAxisExtent), so decoding wider is wasted memory.
                  ProductImageView(image: product.primaryImage, decodeWidth: 240),
                  if (!product.inStock)
                    ColoredBox(
                      color: Colors.black.withValues(alpha: 0.45),
                      child: const Center(
                        child: Text('Out of stock',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (weightHint.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(weightHint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          formatInr(pricing.preGstPrice),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (product.originalPrice != null &&
                          product.originalPrice! > pricing.preGstPrice) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            formatInr(product.originalPrice!),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              decoration: TextDecoration.lineThrough,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
