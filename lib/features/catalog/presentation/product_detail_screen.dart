import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/format/currency.dart';
import '../../../core/pricing/pricing.dart';
import '../../cart/application/cart_controller.dart';
import '../application/catalog_providers.dart';
import '../data/models/product.dart';
import 'widgets/product_image.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  /// Variants carry no id server-side, so selection is by index — as on web.
  int _selectedVariant = 0;
  int _imagePage = 0;

  @override
  Widget build(BuildContext context) {
    final product = ref.watch(productProvider(widget.productId));

    return Scaffold(
      appBar: AppBar(title: const Text('Product')),
      body: product.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorBody(
          message: error is ApiException ? error.message : 'Could not load this product.',
          onRetry: () => ref.invalidate(productProvider(widget.productId)),
        ),
        data: _buildProduct,
      ),
    );
  }

  Widget _buildProduct(Product product) {
    final rates = ref.watch(silverRatesValueProvider);
    final ratesAsync = ref.watch(silverRatesProvider);
    final gstPercent = ref.watch(gstPercentProvider).valueOrNull;

    final variants = product.variants;
    final selected = variants.isEmpty
        ? null
        : variants[_selectedVariant.clamp(0, variants.length - 1)];

    // The whole variant→price recompute: the variant's free-text weight is
    // parsed to grams and passed as the override. A null override falls through
    // to the product's own weight inside the engine.
    final variantGrams = parseGrams(selected?.weight);
    final pricing = computeProductPricing(
      product.toPricingInput(),
      rates,
      gramsOverride: variantGrams,
    );

    final showBreakdown = !product.isFixedPrice && pricing.computed;
    final displayWeight = (selected?.weight.isNotEmpty ?? false)
        ? selected!.weight
        : '${_trimZeros(product.weightInGrams)} g';

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildGallery(product),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(product.name, style: Theme.of(context).textTheme.headlineSmall),
              if (product.material != null) ...[
                const SizedBox(height: 4),
                Text(product.material!,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatInr(pricing.preGstPrice),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (product.originalPrice != null &&
                      product.originalPrice! > pricing.preGstPrice) ...[
                    const SizedBox(width: 10),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        formatInr(product.originalPrice!),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              decoration: TextDecoration.lineThrough,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                  ],
                ],
              ),
              // The web silently swaps to the listed price when rates fail and
              // hides the breakdown entirely, with no indication. Saying so is
              // a deliberate improvement.
              if (!product.isFixedPrice && !pricing.computed) ...[
                const SizedBox(height: 6),
                _PriceBasisNotice(
                  isLoading: ratesAsync.isLoading,
                  failed: ratesAsync.hasError,
                  onRetry: () => ref.invalidate(silverRatesProvider),
                ),
              ],
              const SizedBox(height: 20),
              if (variants.isNotEmpty) ...[
                Text('Size', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(variants.length, (i) {
                    final v = variants[i];
                    return ChoiceChip(
                      selected: i == _selectedVariant,
                      onSelected: (_) => setState(() => _selectedVariant = i),
                      label: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(v.displayLabel),
                          if (v.label.isNotEmpty && v.weight.isNotEmpty)
                            Text(v.weight, style: Theme.of(context).textTheme.labelSmall),
                        ],
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),
              ],
              if (showBreakdown) _PriceBreakdownCard(pricing: pricing, gstPercent: gstPercent),
              const SizedBox(height: 20),
              _SpecificationsCard(
                product: product,
                displayWeight: displayWeight,
                selected: selected,
              ),
              if (product.description != null && product.description!.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Description', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Text(product.description!),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(
                    product.inStock ? Icons.check_circle_outline : Icons.remove_circle_outline,
                    size: 18,
                    color: product.inStock
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 6),
                  Text(product.inStock
                      ? 'In stock (${product.stockAvailable} available)'
                      : 'Out of stock'),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: product.inStock
                    ? () {
                        // The price banked into the cart line is the one the
                        // customer is looking at, for the variant they picked —
                        // the server re-prices at checkout regardless.
                        ref.read(cartProvider.notifier).add(
                              product,
                              unitPrice: pricing.preGstPrice,
                              variant: selected,
                            );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Added to cart'),
                            action: SnackBarAction(
                              label: 'View cart',
                              onPressed: () => context.push('/cart'),
                            ),
                          ),
                        );
                      }
                    : null,
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text('Add to cart'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGallery(Product product) {
    final images = product.images;
    if (images.isEmpty) {
      return const AspectRatio(
        aspectRatio: 1,
        child: ProductImageView(image: null, decodeWidth: 400),
      );
    }

    // The gallery is full-bleed, so decode to the screen width — but no wider.
    final galleryWidth = MediaQuery.sizeOf(context).width;

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: PageView.builder(
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _imagePage = i),
            itemBuilder: (context, i) =>
                ProductImageView(image: images[i], decodeWidth: galleryWidth),
          ),
        ),
        if (images.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                images.length,
                (i) => Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _imagePage
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  static String _trimZeros(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

class _PriceBreakdownCard extends StatelessWidget {
  const _PriceBreakdownCard({required this.pricing, required this.gstPercent});

  final ProductPriceBreakdown pricing;
  final double? gstPercent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Price breakdown', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            _row(
              context,
              'Metal value',
              formatInr(pricing.metalValue!.round()),
              subtitle: '${_grams(pricing.grams!)} g × ${formatRatePerGram(pricing.ratePerGram!)}',
            ),
            // Charge rows appear only when non-zero, matching the web.
            if ((pricing.makingCharge ?? 0) > 0)
              _row(context, 'Making charge', formatInr(pricing.makingCharge!.round())),
            if ((pricing.wastage ?? 0) > 0)
              _row(context, 'Wastage', formatInr(pricing.wastage!.round())),
            const Divider(height: 20),
            _row(
              context,
              'Price (before GST)',
              formatInr(pricing.preGstPrice.round()),
              bold: true,
            ),
            const SizedBox(height: 10),
            Text(
              "Metal value is indicative, based on today's silver rate."
              '${gstPercent != null ? ' GST (${_percent(gstPercent!)}%)' : ' GST'}'
              ' and delivery are added at checkout.',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  static String _grams(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  static String _percent(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  Widget _row(BuildContext context, String label, String value,
      {String? subtitle, bool bold = false}) {
    final theme = Theme.of(context);
    final style = bold
        ? theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)
        : theme.textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: style),
                if (subtitle != null)
                  Text(subtitle,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _SpecificationsCard extends StatelessWidget {
  const _SpecificationsCard({
    required this.product,
    required this.displayWeight,
    required this.selected,
  });

  final Product product;
  final String displayWeight;
  final ProductVariant? selected;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Weight', displayWeight),
      if (product.purity != null && product.purity!.isNotEmpty) ('Purity', product.purity!),
      if (product.material != null) ('Material', product.material!),
      if (selected?.height != null) ('Height', selected!.height!),
      if (selected?.breadth != null) ('Breadth', selected!.breadth!),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Specifications', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...rows.map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(r.$1,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ),
                      Text(r.$2),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

/// Shown when a dynamically-priced product falls back to its listed price.
class _PriceBasisNotice extends StatelessWidget {
  const _PriceBasisNotice({
    required this.isLoading,
    required this.failed,
    required this.onRetry,
  });

  final bool isLoading;
  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return Text('Updating with today’s rate…',
          style: theme.textTheme.labelMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant));
    }

    return Row(
      children: [
        Icon(Icons.info_outline, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            failed
                ? 'Showing the listed price — today’s rate is unavailable.'
                : 'Showing the listed price.',
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        if (failed)
          TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
