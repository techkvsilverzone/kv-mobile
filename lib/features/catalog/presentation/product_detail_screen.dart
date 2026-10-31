import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/format/currency.dart';
import '../../../core/pricing/pricing.dart';
import '../../cart/application/cart_controller.dart';
import '../application/catalog_providers.dart';
import '../data/models/product.dart';
import 'widgets/product_image.dart';
import '../../recently_viewed/recently_viewed.dart';
import 'widgets/product_grid.dart';
import '../../wishlist/wishlist.dart';
import '../../savings/application/installment_payer.dart' show showToast;
import '../../reviews/reviews.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/auth/auth_session.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../../delivery/delivery_check.dart';

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
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(recentlyViewedProvider.notifier).add(widget.productId));
  }

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

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final reviews = ref.watch(productReviewsProvider(product.id)).valueOrNull;
    final related = product.material == null
        ? const <Product>[]
        : (ref.watch(productsInCategoryProvider(product.material!)).valueOrNull ?? const <Product>[])
            .where((p) => p.id != product.id)
            .take(4)
            .toList();
    final original = product.originalPrice ?? 0;
    Widget eyebrow(String t, {IconData? icon}) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            if (icon != null) ...[Icon(icon, size: 12, color: muted), const SizedBox(width: 6)],
            Text(t.toUpperCase(), style: TextStyle(fontSize: 10, letterSpacing: 2, color: muted)),
          ]),
        );

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Stack(children: [
          _buildGallery(product),
          if (product.isNew)
            Positioned(top: 16, left: 16, child: _badge('NEW', Colors.white, Colors.black)),
          if (product.isSale)
            Positioned(top: 16, left: product.isNew ? 64 : 16, child: _badge('SALE', scheme.error, Colors.white)),
        ]),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              eyebrow(product.material ?? ''),
              Text(product.name,
                  style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w400)),
              if (reviews != null && reviews.totalReviews > 0) ...[
                const SizedBox(height: 12),
                Row(children: [
                  StarRow(rating: reviews.averageRating.round(), size: 16),
                  const SizedBox(width: 8),
                  Text('(${reviews.totalReviews} review${reviews.totalReviews != 1 ? 's' : ''})',
                      style: TextStyle(fontSize: 14, color: muted)),
                ]),
              ],
              const SizedBox(height: 16),
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 16, children: [
                Text(formatInr(pricing.preGstPrice),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
                if (original != 0) ...[
                  Text(formatInr(original),
                      style: TextStyle(fontSize: 18, color: muted, decoration: TextDecoration.lineThrough)),
                  Text('${((original - product.price) / original * 100).round()}% off',
                      style: const TextStyle(fontSize: 14, color: Color(0xFF16A34A), fontWeight: FontWeight.w500)),
                ],
              ]),
              if (!product.isFixedPrice && !pricing.computed) ...[
                const SizedBox(height: 6),
                _PriceBasisNotice(
                  isLoading: ratesAsync.isLoading,
                  failed: ratesAsync.hasError,
                  onRetry: () => ref.invalidate(silverRatesProvider),
                ),
              ],
              const SizedBox(height: 24),
              if (showBreakdown) ...[
                _PriceBreakdownCard(pricing: pricing, gstPercent: gstPercent),
                const SizedBox(height: 24),
              ],
              if ((product.description ?? '').isNotEmpty) ...[
                Text(product.description!, style: TextStyle(color: muted, height: 1.6)),
                const SizedBox(height: 24),
              ],
              if (variants.isNotEmpty) ...[
                eyebrow('Select Size'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(variants.length, (i) {
                    final v = variants[i];
                    final on = i == _selectedVariant;
                    return InkWell(
                      onTap: () => setState(() => _selectedVariant = i),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 48),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: on ? scheme.primary.withValues(alpha: 0.1) : null,
                          border: Border.all(color: on ? scheme.primary : scheme.outline),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(v.displayLabel,
                              style: TextStyle(
                                  fontSize: 14,
                                  color: on ? scheme.primary : null,
                                  fontWeight: on ? FontWeight.w500 : FontWeight.w400)),
                          if (v.label.isNotEmpty && v.weight.isNotEmpty)
                            Text(v.weight, style: TextStyle(fontSize: 10, color: muted)),
                        ]),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),
              ],
              _SpecificationsCard(product: product, displayWeight: displayWeight, selected: selected),
              const SizedBox(height: 24),
              eyebrow('Check Delivery', icon: Icons.place_outlined),
              const _PincodeChecker(),
              const SizedBox(height: 24),
              Row(children: [
                Container(
                  decoration: BoxDecoration(
                      border: Border.all(color: scheme.outline), borderRadius: BorderRadius.circular(6)),
                  child: Row(children: [
                    IconButton(
                      tooltip: 'Decrease quantity',
                      onPressed: () => setState(() => _quantity = _quantity > 1 ? _quantity - 1 : 1),
                      icon: const Icon(Icons.remove, size: 16),
                    ),
                    SizedBox(
                        width: 32,
                        child: Text('$_quantity',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                    IconButton(
                      tooltip: 'Increase quantity',
                      onPressed: () => setState(() => _quantity++),
                      icon: const Icon(Icons.add, size: 16),
                    ),
                  ]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: product.inStock
                          ? () {
                              // The price banked into the cart line is the one shown, for
                              // the chosen size — the server re-prices at checkout anyway.
                              ref.read(cartProvider.notifier).add(product,
                                  unitPrice: pricing.preGstPrice, variant: selected, quantity: _quantity);
                              showToast(context, 'Added to Cart', '${_quantity}x ${product.name} added to cart.');
                            }
                          : null,
                      icon: const Icon(Icons.shopping_cart_outlined, size: 16),
                      label: Text(product.inStock ? 'Add to Cart' : 'Out of Stock'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      border: Border.all(color: scheme.outline), borderRadius: BorderRadius.circular(8)),
                  child: WishlistButton(productId: product.id, productName: product.name),
                ),
              ]),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Row(children: [
                for (final (icon, label) in const [
                  (Icons.shield_outlined, 'BIS Hallmarked'),
                  (Icons.local_shipping_outlined, 'Insured Shipping'),
                  (Icons.replay, '7-Day Returns'),
                ])
                  Expanded(
                    child: Row(children: [
                      Icon(icon, size: 16, color: muted),
                      const SizedBox(width: 6),
                      Flexible(child: Text(label, style: TextStyle(fontSize: 12, color: muted))),
                    ]),
                  ),
              ]),
              const SizedBox(height: 32),
              _DetailTabs(productId: product.id, reviews: reviews),
              if (related.isNotEmpty) ...[
                const SizedBox(height: 48),
                const PageHeader(eyebrow: 'You May Also Like', title: 'Related Products'),
              ],
            ],
          ),
        ),
        if (related.isNotEmpty) ...[ProductGrid(products: related), const SizedBox(height: 32)],
      ],
    );
  }

  Widget _badge(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        color: bg,
        child: Text(text, style: TextStyle(fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w500, color: fg)),
      );

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
    final scheme = Theme.of(context).colorScheme;
    final cells = <(String, String, Color?)>[
      if (!product.isFixedPrice) ('Weight', displayWeight, null),
      ('Purity', product.purity ?? '', null),
      if ((selected?.height ?? '').isNotEmpty) ('Height', selected!.height!, null),
      if ((selected?.breadth ?? '').isNotEmpty) ('Breadth', selected!.breadth!, null),
      ('Category', product.material ?? '', null),
      ('Availability', product.inStock ? 'In Stock' : 'Out of Stock',
          product.inStock ? const Color(0xFF16A34A) : scheme.error),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: scheme.secondary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(6)),
      child: LayoutBuilder(
        builder: (context, c) => Wrap(
          runSpacing: 16,
          children: [
            for (final (label, value, color) in cells)
              SizedBox(
                width: c.maxWidth / 2,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label.toUpperCase(),
                      style: TextStyle(fontSize: 12, letterSpacing: 0.8, color: scheme.onSurfaceVariant)),
                  Text(value, style: TextStyle(fontWeight: FontWeight.w500, color: color)),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

/// Delivery check against `GET /delivery/check`: confirms the pincode exists and
/// shows the zone's delivery charge.
class _PincodeChecker extends ConsumerStatefulWidget {
  const _PincodeChecker();

  @override
  ConsumerState<_PincodeChecker> createState() => _PincodeCheckerState();
}

class _PincodeCheckerState extends ConsumerState<_PincodeChecker> {
  final _ctrl = TextEditingController();
  bool _checking = false;
  DeliveryCheck? _result;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    if (_ctrl.text.length != 6) return;
    setState(() {
      _checking = true;
      _result = null;
      _error = null;
    });
    try {
      final r = await ref.read(deliveryRepositoryProvider).check(_ctrl.text);
      if (mounted) setState(() => _result = r);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not check this pincode. Please try again.');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF16A34A);
    final red = Theme.of(context).colorScheme.error;
    final r = _result;
    Widget line(IconData icon, String text, Color color) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: color))),
          ]),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        SizedBox(
          width: 180,
          child: TextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
            decoration: const InputDecoration(hintText: 'Enter 6-digit pincode', isDense: true),
            style: const TextStyle(fontSize: 14),
            onChanged: (_) => setState(() {
              _result = null;
              _error = null;
            }),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: _ctrl.text.length < 6 || _checking ? null : _check,
          child: _checking
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Check'),
        ),
      ]),
      if (_error != null) line(Icons.error_outline, _error!, red),
      if (r != null && !r.available)
        line(Icons.cancel_outlined, r.reason ?? 'Delivery not available to this pincode', red),
      if (r != null && r.available) ...[
        line(
          Icons.check_circle_outline,
          r.verified && r.city != null
              ? 'Delivery available to ${r.city}, ${r.state} — arrives in ${r.estimatedDays ?? '5–7'} business days'
              : 'Delivery available — arrives in ${r.estimatedDays ?? '5–7'} business days',
          green,
        ),
        if (r.verified && r.deliveryFee != null)
          line(Icons.local_shipping_outlined, 'Delivery charge: ${formatInr(r.deliveryFee!)}', green),
      ],
    ]);
  }
}

/// Five stars, the first [rating] filled (web: fill-accent text-primary).
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.rating, this.size = 12, this.onTap});
  final int rating;
  final double size;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var star = 1; star <= 5; star++)
        GestureDetector(
          onTap: onTap == null ? null : () => onTap!(star),
          child: Icon(star <= rating ? Icons.star : Icons.star_border,
              size: size,
              color: star <= rating ? scheme.primary : scheme.onSurfaceVariant.withValues(alpha: 0.3)),
        ),
    ]);
  }
}

/// "Reviews (n)" and "Shipping & Returns" tabs.
class _DetailTabs extends ConsumerStatefulWidget {
  const _DetailTabs({required this.productId, required this.reviews});
  final String productId;
  final ReviewSummary? reviews;

  @override
  ConsumerState<_DetailTabs> createState() => _DetailTabsState();
}

class _DetailTabsState extends ConsumerState<_DetailTabs> {
  int _tab = 0;
  int _rating = 5;
  final _title = TextEditingController();
  final _comment = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _title.dispose();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await ref
          .read(reviewRepositoryProvider)
          .create(widget.productId, rating: _rating, title: _title.text, comment: _comment.text);
      ref.invalidate(productReviewsProvider(widget.productId));
      _title.clear();
      _comment.clear();
      setState(() => _rating = 5);
      if (mounted) showToast(context, 'Review Submitted', 'Thank you for your review!');
    } catch (_) {
      // The web shows nothing on failure; the button just re-enables.
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final authed = ref.watch(authSessionProvider).isAuthenticated;
    final r = widget.reviews;
    final list = r?.reviews ?? const <Review>[];
    TextStyle? h3 = theme.textTheme.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.w600);
    Widget bullets(String title, List<String> items) => Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: h3),
            const SizedBox(height: 8),
            for (final i in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('• $i', style: TextStyle(fontSize: 14, color: muted)),
              ),
          ]),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SegmentedButton<int>(
        segments: [
          ButtonSegment(value: 0, label: Text('Reviews (${r?.totalReviews ?? 0})')),
          const ButtonSegment(value: 1, label: Text('Shipping & Returns')),
        ],
        selected: {_tab},
        showSelectedIcon: false,
        onSelectionChanged: (s) => setState(() => _tab = s.first),
      ),
      const SizedBox(height: 8),
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _tab == 1
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  bullets('Shipping', const [
                    'Free insured shipping on all orders',
                    'Delivery within 5-7 business days across India',
                    'All shipments are fully insured and tamper-proof sealed',
                    'Real-time tracking available after dispatch',
                  ]),
                  bullets('Returns & Exchange', const [
                    'Refunds for wrong/damaged/defective items — filed within 48 hrs, unboxing video required',
                    'Change-of-mind requests: exchange or store credit only, no video needed',
                    'Exchange available for size/design changes',
                    'Refunds processed within 5-7 business days',
                    'Buyback available at prevailing silver rates',
                  ]),
                  bullets('Certification', const [
                    'All products are BIS Hallmarked for purity assurance',
                    'Certificate of authenticity included with every purchase',
                    'Weight verification guarantee',
                  ]),
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24, top: 8),
                      child: Text('No reviews yet. Be the first to review this product!',
                          textAlign: TextAlign.center, style: TextStyle(color: muted)),
                    )
                  else
                    for (final rv in list)
                      Container(
                        padding: const EdgeInsets.only(bottom: 16),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: rv == list.last
                            ? null
                            : BoxDecoration(border: Border(bottom: BorderSide(color: theme.colorScheme.outline))),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                            StarRow(rating: rv.rating),
                            Text(rv.userName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                            if (rv.createdAt != null)
                              Text(DateFormat('d/M/y').format(rv.createdAt!.toLocal()),
                                  style: TextStyle(fontSize: 12, color: muted)),
                          ]),
                          const SizedBox(height: 8),
                          if (rv.title.isNotEmpty)
                            Text(rv.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                          Text(rv.comment, style: TextStyle(fontSize: 14, color: muted)),
                        ]),
                      ),
                  if (authed) ...[
                    const Divider(height: 1),
                    const SizedBox(height: 24),
                    Text('Write a Review', style: h3),
                    const SizedBox(height: 16),
                    const Text('Rating', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    StarRow(rating: _rating, size: 24, onTap: (v) => setState(() => _rating = v)),
                    const SizedBox(height: 16),
                    TextField(
                        controller: _title,
                        decoration: const InputDecoration(labelText: 'Title', hintText: 'Summary of your review')),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _comment,
                      maxLines: 4,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                          labelText: 'Your Review',
                          hintText: 'Tell us about your experience with this product...',
                          alignLabelWithHint: true),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton(
                        onPressed: _comment.text.isEmpty || _submitting ? null : _submit,
                        child: Text(_submitting ? 'Submitting...' : 'Submit Review'),
                      ),
                    ),
                  ],
                ]),
        ),
      ),
    ]);
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
