import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/format/currency.dart';
import '../../../../core/pricing/pricing.dart';
import '../../../cart/application/cart_controller.dart';
import '../../../savings/application/installment_payer.dart' show showToast;
import '../../../wishlist/wishlist.dart';
import '../../data/models/product.dart';
import 'product_image.dart';

/// Grid tile, as kv-ui ProductCard.tsx: image carousel with New / Sale / Out of
/// Stock badges and quick cart + wishlist actions (always shown — a phone has no
/// hover), then category, serif name, live pre-GST price and variant weights.
class ProductCard extends ConsumerWidget {
  const ProductCard({super.key, required this.product, required this.rates, required this.onTap});

  final Product product;
  final List<MetalRate> rates;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final pricing = computeProductPricing(product.toPricingInput(), rates);
    final weights = product.variants.map((v) => v.weight.trim()).where((w) => w.isNotEmpty).join(' / ');

    void addToCart() {
      if (!product.inStock) {
        showToast(context, 'Out of Stock', '${product.name} is currently unavailable.', error: true);
        return;
      }
      ref.read(cartProvider.notifier).add(product, unitPrice: pricing.preGstPrice);
      showToast(context, 'Added to Cart', '${product.name} has been added to your cart.');
    }

    Widget badge(String text, Color bg, Color fg) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
          child: Text(text.toUpperCase(),
              style: TextStyle(fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w500, color: fg)),
        );

    Widget action(Widget child) => Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 8)],
          ),
          child: child,
        );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: scheme.secondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.outline.withValues(alpha: 0.6)),
              ),
              child: Stack(fit: StackFit.expand, children: [
                _Carousel(images: product.images),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (product.isNew) badge('New', scheme.primary, scheme.onPrimary),
                    if (product.isSale) badge('Sale', scheme.error, scheme.onError),
                    if (!product.inStock) badge('Out of Stock', scheme.surface.withValues(alpha: 0.9), muted),
                  ]),
                ),
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    action(IconButton(
                      iconSize: 16,
                      tooltip: 'Add ${product.name} to cart',
                      onPressed: product.inStock ? addToCart : null,
                      icon: const Icon(Icons.shopping_cart_outlined),
                    )),
                    const SizedBox(width: 8),
                    action(WishlistButton(productId: product.id, productName: product.name, size: 16)),
                  ]),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Text((product.material ?? '').toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, letterSpacing: 1.8, color: muted)),
          const SizedBox(height: 2),
          Text(product.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily: 'PlayfairDisplay', fontSize: 17, fontWeight: FontWeight.w500, color: scheme.onSurface)),
          const SizedBox(height: 4),
          Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, children: [
            Text(formatInr(pricing.preGstPrice),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
            if ((product.originalPrice ?? 0) != 0)
              Text(formatInr(product.originalPrice!),
                  style: TextStyle(
                      fontSize: 12,
                      color: muted,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: muted.withValues(alpha: 0.5))),
          ]),
          if (!product.isFixedPrice && weights.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(weights,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: muted, letterSpacing: 0.4)),
          ],
        ],
      ),
    );
  }
}

/// Swipeable image gallery with dots (kv-ui ProductImageCarousel).
class _Carousel extends StatefulWidget {
  const _Carousel({required this.images});
  final List<ProductImage> images;

  @override
  State<_Carousel> createState() => _CarouselState();
}

class _CarouselState extends State<_Carousel> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    // Grid tiles are ~240 logical px at most, so decoding wider is wasted memory.
    if (images.length <= 1) {
      return ProductImageView(image: images.firstOrNull, decodeWidth: 240);
    }
    return Stack(fit: StackFit.expand, children: [
      PageView.builder(
        itemCount: images.length,
        onPageChanged: (i) => setState(() => _page = i),
        itemBuilder: (_, i) => ProductImageView(image: images[i], decodeWidth: 240),
      ),
      Positioned(
        bottom: 60,
        left: 0,
        right: 0,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < images.length; i++)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: i == _page ? 0.95 : 0.5),
              ),
            ),
        ]),
      ),
    ]);
  }
}
