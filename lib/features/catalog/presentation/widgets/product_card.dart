import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/pricing/pricing.dart';
import '../../../../core/ui/kv_ui.dart';
import '../../../cart/application/cart_controller.dart';
import '../../../wishlist/wishlist.dart';
import '../../data/models/product.dart';
import 'product_image.dart';

/// Product tile: image with wishlist heart and badges, then name, weight,
/// live pre-GST price and a quick-add button.
/// Height of everything below the square image in a [ProductCard].
const productCardInfoHeight = 108.0;

class ProductCard extends ConsumerWidget {
  const ProductCard({super.key, required this.product, required this.rates, required this.onTap});

  final Product product;
  final List<MetalRate> rates;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pricing = computeProductPricing(product.toPricingInput(), rates);
    final weights = product.variants.map((v) => v.weight.trim()).where((w) => w.isNotEmpty).toList();
    final weightLine = !product.isFixedPrice && weights.isNotEmpty
        ? (weights.length > 2 ? '${weights.first} – ${weights.last}' : weights.join(' · '))
        : (product.weightInGrams > 0 ? '${_trim(product.weightInGrams)} g' : product.material ?? '');

    void addToCart() {
      if (!product.inStock) return;
      HapticFeedback.lightImpact();
      ref.read(cartProvider.notifier).add(product, unitPrice: pricing.preGstPrice);
      showKvToast(context, 'Added to cart',
          message: product.name, actionLabel: 'View', onAction: () => context.go('/cart'));
    }

    return Semantics(
      button: true,
      label: product.name,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Kv.radiusSm),
              child: Stack(fit: StackFit.expand, children: [
                Container(color: const Color(0xFFEFF1F4)),
                ProductImageView(image: product.primaryImage, decodeWidth: 260),
                if (!product.inStock) Container(color: Colors.white.withValues(alpha: 0.55)),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (!product.inStock)
                      const StatusPill('Sold out')
                    else if (product.isSale)
                      const StatusPill('Sale', tone: PillTone.danger)
                    else if (product.isNew)
                      const StatusPill('New', tone: PillTone.info),
                  ]),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.92),
                    shape: const CircleBorder(),
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: WishlistButton(productId: product.id, productName: product.name, size: 18),
                    ),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          // Cards sit in fixed-height grid cells: name and weight on top, price pinned
          // to the bottom so prices line up across a row whatever the name length.
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.3, color: Kv.ink)),
              const SizedBox(height: 2),
              Text(weightLine,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Kv.muted)),
              const Spacer(),
              Row(children: [
                Expanded(child: PriceText(pricing.preGstPrice, original: product.originalPrice, size: 15)),
                SizedBox(
                  width: 34,
                  height: 34,
                  child: IconButton.filledTonal(
                    padding: EdgeInsets.zero,
                    tooltip: 'Add ${product.name} to cart',
                    style: IconButton.styleFrom(backgroundColor: Kv.blueSoft, foregroundColor: Kv.blue),
                    onPressed: product.inStock ? addToCart : null,
                    icon: const Icon(Icons.add_rounded, size: 20),
                  ),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  static String _trim(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}
