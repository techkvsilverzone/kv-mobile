import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/format/currency.dart';
import '../../../core/pricing/pricing.dart';
import '../../../core/ui/kv_ui.dart';
import '../../cart/application/cart_controller.dart';
import '../../delivery/delivery_check.dart';
import '../../recently_viewed/recently_viewed.dart';
import '../../reviews/reviews.dart';
import '../../reviews/reviews_page.dart';
import '../../wishlist/wishlist.dart';
import '../application/catalog_providers.dart';
import '../data/models/product.dart';
import 'widgets/product_grid.dart';
import 'widgets/product_image.dart';

/// More variants than this open a sheet instead of a chip row.
const _maxInlineVariants = 6;

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  /// Variants carry no id server-side, so selection is by index — as on web.
  int _selectedVariant = 0;
  int _imagePage = 0;
  int _quantity = 1;
  bool _descExpanded = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(recentlyViewedProvider.notifier).add(widget.productId));
  }

  @override
  Widget build(BuildContext context) {
    final product = ref.watch(productProvider(widget.productId));
    return product.when(
      loading: () => Scaffold(appBar: AppBar(), body: const _DetailSkeleton()),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: EmptyState(
            icon: Icons.cloud_off_rounded,
            title: "Couldn't load this product",
            message: error is ApiException
                ? error.message
                : 'Check your connection and try again.',
            actionLabel: 'Try again',
            onAction: () => ref.invalidate(productProvider(widget.productId)),
          ),
        ),
      ),
      data: _buildProduct,
    );
  }

  Widget _buildProduct(Product product) {
    final rates = ref.watch(silverRatesValueProvider);
    final gstPercent = ref.watch(gstPercentProvider).valueOrNull;

    final variants = product.variants;
    final selected = variants.isEmpty
        ? null
        : variants[_selectedVariant.clamp(0, variants.length - 1)];

    // The whole variant→price recompute: the variant's free-text weight is
    // parsed to grams and passed as the override. A null override falls through
    // to the product's own weight inside the engine.
    final pricing = computeProductPricing(product.toPricingInput(), rates,
        gramsOverride: parseGrams(selected?.weight));

    final showBreakdown = !product.isFixedPrice && pricing.computed;
    final displayWeight = (selected?.weight.isNotEmpty ?? false)
        ? selected!.weight
        : '${_trimZeros(product.weightInGrams)} g';

    final reviews = ref.watch(productReviewsProvider(product.id)).valueOrNull;
    final related = product.material == null
        ? const <Product>[]
        : (ref
                    .watch(productsInCategoryProvider(product.material!))
                    .valueOrNull ??
                const <Product>[])
            .where((p) => p.id != product.id)
            .take(10)
            .toList();
    final original = product.originalPrice ?? 0;
    final percentOff = original > 0
        ? ((original - product.price) / original * 100).round()
        : 0;
    final width = MediaQuery.sizeOf(context).width;

    void openReviews() => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) =>
            ReviewsPage(productId: product.id, productName: product.name)));

    void addToCart() {
      HapticFeedback.mediumImpact();
      // The price banked into the cart line is the one shown, for the chosen
      // size — the server re-prices at checkout anyway.
      ref.read(cartProvider.notifier).add(product,
          unitPrice: pricing.preGstPrice,
          variant: selected,
          quantity: _quantity);
      showKvToast(context, 'Added to cart',
          message: '$_quantity × ${product.name}',
          actionLabel: 'View cart',
          onAction: () => context.go('/cart'));
    }

    Widget gap([double h = Kv.gap]) => SizedBox(height: h);
    const pad = EdgeInsets.symmetric(horizontal: Kv.pad);

    return Scaffold(
      bottomNavigationBar: BottomActionBar(
        leading: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(formatInr(pricing.preGstPrice * _quantity),
                    style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3)),
              ),
              Text(product.inStock ? '+ GST at checkout' : 'Out of stock',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: product.inStock ? Kv.subtle : Kv.danger)),
            ]),
        action: Row(mainAxisSize: MainAxisSize.min, children: [
          if (product.inStock) ...[
            QuantityStepper(
                compact: true,
                value: _quantity,
                onChanged: (v) => setState(() => _quantity = v)),
            const SizedBox(width: 10),
          ],
          FilledButton(
            onPressed: product.inStock ? addToCart : null,
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20)),
            child: Text(product.inStock ? 'Add to cart' : 'Sold out'),
          ),
        ]),
      ),
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: width,
          backgroundColor: Kv.surface,
          leading: _RoundButton(
            tooltip: 'Back',
            icon: Icons.arrow_back_rounded,
            onTap: () => context.canPop() ? context.pop() : context.go('/shop'),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Material(
                color: Colors.white.withValues(alpha: 0.92),
                shape: const CircleBorder(),
                child: SizedBox(
                    width: 40,
                    height: 40,
                    child: WishlistButton(
                        productId: product.id, productName: product.name)),
              ),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.pin,
            background: _Gallery(
              product: product,
              page: _imagePage,
              onPage: (i) => setState(() => _imagePage = i),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Title + price
            _Section(
              padding: const EdgeInsets.fromLTRB(Kv.pad, 16, Kv.pad, 20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((product.material ?? '').isNotEmpty)
                      Text(product.material!,
                          style: const TextStyle(
                              fontSize: 12.5,
                              color: Kv.muted,
                              fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(product.name,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                            letterSpacing: -0.3)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: openReviews,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: (reviews?.totalReviews ?? 0) > 0
                            ? Row(mainAxisSize: MainAxisSize.min, children: [
                                StarRow(
                                    rating: reviews!.averageRating, size: 16),
                                const SizedBox(width: 6),
                                Text(reviews.averageRating.toStringAsFixed(1),
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                                Text(
                                    '  ·  ${reviews.totalReviews} review${reviews.totalReviews != 1 ? 's' : ''}',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: Kv.blue,
                                        fontWeight: FontWeight.w500)),
                              ])
                            : const Text('No reviews yet',
                                style:
                                    TextStyle(fontSize: 13, color: Kv.muted)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        runSpacing: 4,
                        children: [
                          Text(formatInr(pricing.preGstPrice),
                              style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.4)),
                          if (original > 0) ...[
                            Text(formatInr(original),
                                style: const TextStyle(
                                    fontSize: 16,
                                    color: Kv.subtle,
                                    decoration: TextDecoration.lineThrough)),
                            if (percentOff > 0)
                              StatusPill('$percentOff% off',
                                  tone: PillTone.success),
                          ],
                        ]),
                    const SizedBox(height: 4),
                    // The price uses the server's own rate, so it is what checkout charges.
                    Row(children: [
                      Text(
                        showBreakdown
                            ? 'Priced at today’s silver rate · GST extra'
                            : 'GST extra at checkout',
                        style: const TextStyle(fontSize: 12.5, color: Kv.muted),
                      ),
                      if (showBreakdown)
                        TextButton(
                          style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6)),
                          onPressed: () => showKvSheet<void>(context,
                              title: 'Price details',
                              builder: (_) => _PriceBreakdown(
                                  pricing: pricing, gstPercent: gstPercent)),
                          child: const Text('Details',
                              style: TextStyle(fontSize: 12.5)),
                        ),
                    ]),
                  ]),
            ),
            // Size
            if (variants.isNotEmpty) ...[
              gap(8),
              _Section(
                padding: const EdgeInsets.fromLTRB(Kv.pad, 16, Kv.pad, 16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                          TextSpan(children: [
                            const TextSpan(
                                text: 'Size',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                            if (selected != null)
                              TextSpan(
                                  text:
                                      '  ${selected.displayLabel}${selected.label.isNotEmpty && selected.weight.isNotEmpty ? ' · ${selected.weight}' : ''}',
                                  style: const TextStyle(color: Kv.muted)),
                          ]),
                          style: const TextStyle(fontSize: 15)),
                      const SizedBox(height: 12),
                      if (variants.length > _maxInlineVariants)
                        OutlinedButton(
                          onPressed: () => _pickVariant(variants),
                          style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48)),
                          child: Row(children: [
                            Expanded(
                                child: Text(
                                    selected?.displayLabel ?? 'Choose a size')),
                            const Icon(Icons.expand_more_rounded),
                          ]),
                        )
                      else
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          for (var i = 0; i < variants.length; i++)
                            _VariantChip(
                              variant: variants[i],
                              selected: i == _selectedVariant,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedVariant = i);
                              },
                            ),
                        ]),
                    ]),
              ),
            ],
            gap(8),
            // Delivery
            _Section(
              padding: const EdgeInsets.fromLTRB(Kv.pad, 16, Kv.pad, 16),
              child: const _PincodeChecker(),
            ),
            gap(8),
            // Details
            _Section(
              padding: const EdgeInsets.fromLTRB(Kv.pad, 20, Kv.pad, 8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Product details',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
                    _SpecGrid(
                        product: product,
                        displayWeight: displayWeight,
                        selected: selected),
                    if ((product.description ?? '').isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _Description(
                        text: product.description!,
                        expanded: _descExpanded,
                        onToggle: () =>
                            setState(() => _descExpanded = !_descExpanded),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const _TrustRow(),
                    const SizedBox(height: 8),
                    const Divider(),
                    const _InfoTile(
                      icon: Icons.local_shipping_outlined,
                      title: 'Shipping & returns',
                      groups: [
                        (
                          'Shipping',
                          [
                            'Free insured shipping on all orders',
                            'Delivery within 5-7 business days across India',
                            'All shipments are fully insured and tamper-proof sealed',
                            'Real-time tracking available after dispatch',
                          ]
                        ),
                        (
                          'Returns & exchange',
                          [
                            'Refunds for wrong/damaged/defective items — filed within 48 hrs, unboxing video required',
                            'Change-of-mind requests: exchange or store credit only, no video needed',
                            'Exchange available for size/design changes',
                            'Refunds processed within 5-7 business days',
                            'Buyback available at prevailing silver rates',
                          ]
                        ),
                      ],
                    ),
                    const Divider(),
                    const _InfoTile(
                      icon: Icons.verified_outlined,
                      title: 'Certification',
                      groups: [
                        (
                          '',
                          [
                            'All products are BIS Hallmarked for purity assurance',
                            'Certificate of authenticity included with every purchase',
                            'Weight verification guarantee',
                          ]
                        ),
                      ],
                    ),
                  ]),
            ),
            gap(8),
            // Reviews
            _Section(
              padding: const EdgeInsets.only(top: 20, bottom: 20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeader(
                      title: 'Reviews',
                      action:
                          (reviews?.totalReviews ?? 0) > 0 ? 'See all' : null,
                      onAction: openReviews,
                    ),
                    Padding(
                        padding: pad,
                        child: _ReviewsPreview(
                            productId: product.id,
                            reviews: reviews,
                            onSeeAll: openReviews)),
                  ]),
            ),
            if (related.isNotEmpty) ...[
              gap(8),
              _Section(
                padding: const EdgeInsets.only(top: 20, bottom: 24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionHeader(title: 'You may also like'),
                      ProductCarousel(products: related),
                    ]),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  Future<void> _pickVariant(List<ProductVariant> variants) async {
    final i = await showKvSheet<int>(
      context,
      title: 'Choose a size',
      builder: (ctx) => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            for (var i = 0; i < variants.length; i++)
              ListTile(
                title: Text(variants[i].displayLabel),
                subtitle: variants[i].label.isNotEmpty &&
                        variants[i].weight.isNotEmpty
                    ? Text(variants[i].weight)
                    : null,
                trailing: i == _selectedVariant
                    ? const Icon(Icons.check_rounded, color: Kv.blue)
                    : null,
                onTap: () => Navigator.pop(ctx, i),
              ),
          ]),
    );
    if (i != null) setState(() => _selectedVariant = i);
  }

  static String _trimZeros(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

/// White band on the grey page; a Material so tiles inside keep their ink.
class _Section extends StatelessWidget {
  const _Section({required this.padding, required this.child});
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
      color: Kv.surface, child: Padding(padding: padding, child: child));
}

class _RoundButton extends StatelessWidget {
  const _RoundButton(
      {required this.icon, required this.onTap, required this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) => Center(
        child: Material(
          color: Colors.white.withValues(alpha: 0.92),
          shape: const CircleBorder(),
          child: SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
                tooltip: tooltip,
                onPressed: onTap,
                icon: Icon(icon, size: 22, color: Kv.ink)),
          ),
        ),
      );
}

class _Gallery extends StatelessWidget {
  const _Gallery(
      {required this.product, required this.page, required this.onPage});
  final Product product;
  final int page;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final images = product.images;
    // Full-bleed, so decode to the screen width — but no wider.
    final width = MediaQuery.sizeOf(context).width;
    return Stack(fit: StackFit.expand, children: [
      Container(color: const Color(0xFFEFF1F4)),
      if (images.isEmpty)
        ProductImageView(image: null, decodeWidth: width)
      else
        PageView.builder(
          itemCount: images.length,
          onPageChanged: onPage,
          itemBuilder: (context, i) =>
              ProductImageView(image: images[i], decodeWidth: width),
        ),
      Positioned(
        left: Kv.pad,
        bottom: 14,
        child: Row(children: [
          if (!product.inStock)
            const StatusPill('Sold out')
          else ...[
            if (product.isSale) const StatusPill('Sale', tone: PillTone.danger),
            if (product.isSale && product.isNew) const SizedBox(width: 6),
            if (product.isNew) const StatusPill('New', tone: PillTone.info),
          ],
        ]),
      ),
      if (images.length > 1)
        Positioned(
          left: 0,
          right: 0,
          bottom: 18,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < images.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == page ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                    color: i == page
                        ? Kv.ink
                        : Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(3)),
              ),
          ]),
        ),
    ]);
  }
}

class _VariantChip extends StatelessWidget {
  const _VariantChip(
      {required this.variant, required this.selected, required this.onTap});
  final ProductVariant variant;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? Kv.blueSoft : Kv.surface,
          shape: RoundedRectangleBorder(
              borderRadius: Kv.smallRadius,
              side: BorderSide(
                  color: selected ? Kv.blue : Kv.line,
                  width: selected ? 1.5 : 1)),
          child: InkWell(
            borderRadius: Kv.smallRadius,
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minWidth: 64, minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(variant.displayLabel,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: selected ? Kv.blueDark : Kv.ink)),
                    if (variant.label.isNotEmpty && variant.weight.isNotEmpty)
                      Text(variant.weight,
                          style:
                              const TextStyle(fontSize: 11.5, color: Kv.muted)),
                  ]),
            ),
          ),
        ),
      );
}

class _PriceBreakdown extends StatelessWidget {
  const _PriceBreakdown({required this.pricing, required this.gstPercent});

  final ProductPriceBreakdown pricing;
  final double? gstPercent;

  @override
  Widget build(BuildContext context) {
    Widget row(String label, String value,
            {String? subtitle, bool bold = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                bold ? FontWeight.w700 : FontWeight.w400)),
                    if (subtitle != null)
                      Text(subtitle,
                          style:
                              const TextStyle(fontSize: 12.5, color: Kv.muted)),
                  ]),
            ),
            Text(value,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
          ]),
        );
    return ListView(
      shrinkWrap: true,
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 20 + MediaQuery.paddingOf(context).bottom),
      children: [
        row('Metal value', formatInr(pricing.metalValue!.round()),
            subtitle:
                '${_grams(pricing.grams!)} g × ${formatRatePerGram(pricing.ratePerGram!)}'),
        // Charge rows appear only when non-zero, matching the web.
        if ((pricing.makingCharge ?? 0) > 0)
          row('Making charge', formatInr(pricing.makingCharge!.round())),
        if ((pricing.wastage ?? 0) > 0)
          row('Wastage', formatInr(pricing.wastage!.round())),
        const Divider(height: 20),
        row('Price (before GST)', formatInr(pricing.preGstPrice.round()),
            bold: true),
        const SizedBox(height: 10),
        Text(
          "Metal value is indicative, based on today's silver rate."
          '${gstPercent != null ? ' GST (${_percent(gstPercent!)}%)' : ' GST'}'
          ' and delivery are added at checkout.',
          style: const TextStyle(fontSize: 12.5, color: Kv.muted, height: 1.4),
        ),
      ],
    );
  }

  static String _grams(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  static String _percent(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

/// Key specs, two per row.
class _SpecGrid extends StatelessWidget {
  const _SpecGrid(
      {required this.product,
      required this.displayWeight,
      required this.selected});

  final Product product;
  final String displayWeight;
  final ProductVariant? selected;

  @override
  Widget build(BuildContext context) {
    final cells = <(String, String, Color?)>[
      // No weight on record (e.g. paper frames): leave the cell out rather than say "0 g".
      if (!product.isFixedPrice &&
          (selected?.weight.isNotEmpty == true || product.weightInGrams > 0))
        ('Weight', displayWeight, null),
      if ((product.purity ?? '').isNotEmpty) ('Purity', product.purity!, null),
      if ((selected?.height ?? '').isNotEmpty)
        ('Height', selected!.height!, null),
      if ((selected?.breadth ?? '').isNotEmpty)
        ('Breadth', selected!.breadth!, null),
      if ((product.material ?? '').isNotEmpty)
        ('Category', product.material!, null),
      (
        'Availability',
        product.inStock ? 'In stock' : 'Out of stock',
        product.inStock ? Kv.success : Kv.danger
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final (label, value, color) in cells)
          Container(
            width: (c.maxWidth - 8) / 2,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration:
                BoxDecoration(color: Kv.bg, borderRadius: Kv.smallRadius),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12,
                      color: Kv.muted,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color ?? Kv.ink)),
            ]),
          ),
      ]),
    );
  }
}

class _Description extends StatelessWidget {
  const _Description(
      {required this.text, required this.expanded, required this.onToggle});
  final String text;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 14.5, color: Kv.ink, height: 1.55);
    return LayoutBuilder(builder: (context, c) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: style),
        maxLines: 4,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: c.maxWidth);
      final long = tp.didExceedMaxLines;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(text,
            style: style,
            maxLines: expanded ? null : 4,
            overflow: expanded ? null : TextOverflow.ellipsis),
        if (long)
          GestureDetector(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(expanded ? 'Show less' : 'Read more',
                  style: const TextStyle(
                      color: Kv.blue,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
            ),
          ),
      ]);
    });
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow();

  @override
  Widget build(BuildContext context) => Row(children: [
        for (final (icon, label) in const [
          (Icons.verified_outlined, 'BIS hallmarked'),
          (Icons.local_shipping_outlined, 'Insured shipping'),
          (Icons.autorenew_rounded, '7-day returns'),
        ])
          Expanded(
            child: Column(children: [
              Icon(icon, size: 22, color: Kv.blue),
              const SizedBox(height: 6),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Kv.muted)),
            ]),
          ),
      ]);
}

class _InfoTile extends StatelessWidget {
  const _InfoTile(
      {required this.icon, required this.title, required this.groups});
  final IconData icon;
  final String title;
  final List<(String, List<String>)> groups;

  @override
  Widget build(BuildContext context) => Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          leading: Icon(icon, color: Kv.ink, size: 22),
          title: Text(title,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          children: [
            for (final (heading, items) in groups) ...[
              if (heading.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 6),
                  child: Text(heading,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              for (final i in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 7, right: 10),
                          child: CircleAvatar(
                              radius: 2.5, backgroundColor: Kv.subtle),
                        ),
                        Expanded(
                            child: Text(i,
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    color: Kv.muted,
                                    height: 1.45))),
                      ]),
                ),
              const SizedBox(height: 6),
            ],
          ],
        ),
      );
}

class _ReviewsPreview extends ConsumerWidget {
  const _ReviewsPreview(
      {required this.productId, required this.reviews, required this.onSeeAll});
  final String productId;
  final ReviewSummary? reviews;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authed = ref.watch(authSessionProvider).isAuthenticated;
    final r = reviews;
    final list = r?.reviews ?? const <Review>[];
    final write = authed
        ? OutlinedButton.icon(
            onPressed: () => showWriteReviewSheet(context, productId),
            icon: const Icon(Icons.rate_review_outlined, size: 20),
            label: const Text('Write a review'),
          )
        : null;
    if (list.isEmpty) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(
          authed
              ? 'No reviews yet. Be the first to share what you think.'
              : 'No reviews yet.',
          style: const TextStyle(color: Kv.muted),
        ),
        if (write != null) ...[const SizedBox(height: 12), write],
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ReviewSummaryCard(summary: r!),
      for (final rv in list.take(2)) ...[
        const SizedBox(height: 12),
        ReviewTile(review: rv)
      ],
      const SizedBox(height: 12),
      Row(children: [
        if (list.length > 2) ...[
          Expanded(
            child: TextButton(
                onPressed: onSeeAll,
                child: Text('See all ${r.totalReviews} reviews')),
          ),
        ],
        if (write != null) Expanded(child: write),
      ]),
    ]);
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
    FocusScope.of(context).unfocus();
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
      if (mounted) {
        setState(() => _error = 'Could not check this pincode. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    Widget line(IconData icon, String text, Color color) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
                child: Text(text,
                    style:
                        TextStyle(fontSize: 13, color: color, height: 1.35))),
          ]),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Icon(Icons.location_on_outlined, size: 20),
        SizedBox(width: 8),
        Text('Check delivery',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 12),
      TextField(
        controller: _ctrl,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6)
        ],
        onSubmitted: (_) => _check(),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Enter 6-digit pincode',
          contentPadding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: TextButton(
              onPressed: _ctrl.text.length < 6 || _checking ? null : _check,
              child: _checking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Check'),
            ),
          ),
        ),
        style: const TextStyle(fontSize: 15, letterSpacing: 1),
        onChanged: (_) => setState(() {
          _result = null;
          _error = null;
        }),
      ),
      if (_error != null) line(Icons.error_outline, _error!, Kv.danger),
      if (r != null && !r.available)
        line(Icons.cancel_outlined,
            r.reason ?? 'Delivery not available to this pincode', Kv.danger),
      if (r != null && r.available) ...[
        line(
          Icons.check_circle_outline,
          r.verified && r.city != null
              ? 'Delivers to ${r.city}, ${r.state} in ${r.estimatedDays ?? '5–7'} business days'
              : 'Delivery available — arrives in ${r.estimatedDays ?? '5–7'} business days',
          Kv.success,
        ),
        if (r.verified && r.deliveryFee != null)
          line(Icons.local_shipping_outlined,
              'Delivery charge: ${formatInr(r.deliveryFee!)}', Kv.success),
      ],
    ]);
  }
}

/// Shown when a dynamically-priced product falls back to its listed price.
class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) => KvShimmer(
        child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            children: const [
              AspectRatio(aspectRatio: 1, child: KvSkeleton(radius: 0)),
              Padding(
                padding: EdgeInsets.all(Kv.pad),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      KvSkeleton(width: 80, height: 12),
                      SizedBox(height: 10),
                      KvSkeleton(width: 260, height: 22),
                      SizedBox(height: 14),
                      KvSkeleton(width: 120, height: 14),
                      SizedBox(height: 16),
                      KvSkeleton(width: 140, height: 28),
                      SizedBox(height: 24),
                      KvSkeleton(height: 64, radius: Kv.radiusSm),
                    ]),
              ),
            ]),
      );
}
