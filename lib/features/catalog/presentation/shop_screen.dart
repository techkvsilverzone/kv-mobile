import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/format/currency.dart';
import '../../cart/application/cart_controller.dart';
import '../application/catalog_providers.dart';
import '../data/catalog_repository.dart';
import 'widgets/product_card.dart';

/// Search debounce. The web has none — it refires on every keystroke — so this
/// is a deliberate divergence: on mobile, unthrottled requests over a cellular
/// connection are far more costly.
const _searchDebounce = Duration(milliseconds: 400);

/// Distance from the bottom at which the next page is requested, matching the
/// web's `rootMargin: '400px'` prefetch.
const _loadMoreExtent = 400.0;

// kv-ui Shop.tsx price slider: fixed ₹100–₹5,000, step 100, debounced 700 ms.
const priceMin = 100.0;
const priceMax = 5000.0;
const _priceDebounce = Duration(milliseconds: 700);

const _metals = ['Silver', 'Gold 22K'];
const _priceRanges = [
  ('Under ₹500', '0-500'),
  ('₹500 - ₹1,000', '500-1000'),
  ('₹1,000 - ₹2,000', '1000-2000'),
  ('Above ₹5,000', '5000+'),
];

/// Web `getPriceBounds` for a preset bucket ("500-1000", "5000+").
(double?, double?) priceBounds(String range) {
  if (range.isEmpty) return (null, null);
  if (range.endsWith('+')) return (double.tryParse(range.replaceAll('+', '')), null);
  final parts = range.split('-');
  return (double.tryParse(parts.first), parts.length > 1 ? double.tryParse(parts[1]) : null);
}

/// kv-ui pages/Shop.tsx: search, live filters (categories + subcategories,
/// price slider or preset, metal, tags), sort, result count, infinite scroll.
class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key, this.initialCategory, this.initialSearch});

  /// `?category=` — opens pre-filtered to this category.
  final String? initialCategory;

  /// `?search=` — opens with this search term.
  final String? initialSearch;

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  final _scrollController = ScrollController();
  late final _searchController = TextEditingController(text: widget.initialSearch ?? '');
  Timer? _debounce;

  List<String> _categories = [];
  List<String> _subcategories = [];
  List<String> _tags = [];
  List<String> _metals = [];
  String _priceRange = '';
  RangeValues? _priceSlider;
  ProductSort _sort = ProductSort.newest;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    final category = widget.initialCategory;
    if (category != null && category.isNotEmpty) _categories = [category];
    Future.microtask(_apply);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  ProductFilters get _filters {
    // The slider (when set) overrides the presets; a handle at an extreme means
    // "no cap" on that end.
    final slider = _priceSlider;
    final (min, max) = slider != null
        ? (
            slider.start > priceMin ? slider.start : null,
            slider.end < priceMax ? slider.end : null,
          )
        : priceBounds(_priceRange);
    final search = _searchController.text;
    return ProductFilters(
      categories: _categories,
      subcategories: _subcategories,
      tags: _tags,
      metals: _metals,
      minPrice: min,
      maxPrice: max,
      search: search.isEmpty ? null : search,
      sort: _sort,
    );
  }

  Future<void> _apply() => ref.read(productListProvider.notifier).applyFilters(_filters);

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < _loadMoreExtent) {
      ref.read(productListProvider.notifier).loadMore();
    }
  }

  /// Every filter change clears the search, as on the web.
  void _setFilter(VoidCallback change) {
    _debounce?.cancel();
    _searchController.clear();
    setState(change);
    _apply();
  }

  void _clearAll() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _categories = [];
      _subcategories = [];
      _tags = [];
      _metals = [];
      _priceRange = '';
      _priceSlider = null;
    });
    _apply();
  }

  /// Typing a search clears every filter.
  void _onSearchChanged(String value) {
    setState(() {
      _categories = [];
      _subcategories = [];
      _tags = [];
      _metals = [];
      _priceRange = '';
      _priceSlider = null;
    });
    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, _apply);
  }

  List<String> _toggled(List<String> list, String v) =>
      list.contains(v) ? (List.of(list)..remove(v)) : [...list, v];

  void _toggleCategory(CategoryNode c) => _setFilter(() {
        _categories = _toggled(_categories, c.name);
        // Deselecting a category drops its selected subcategories.
        _subcategories = _subcategories.where((s) => !c.subcategories.contains(s)).toList();
      });

  Future<void> _openFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) {
          void update(VoidCallback fn) {
            fn();
            setSheet(() {});
          }

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.85,
            maxChildSize: 0.95,
            builder: (context, scroll) => ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                Text('Filters', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                _FilterPanel(
                  categories: _categories,
                  subcategories: _subcategories,
                  tags: _tags,
                  metals: _metals,
                  priceRange: _priceRange,
                  priceSlider: _priceSlider,
                  onCategory: (c) => update(() => _toggleCategory(c)),
                  onSubcategory: (s) =>
                      update(() => _setFilter(() => _subcategories = _toggled(_subcategories, s))),
                  onTag: (t) => update(() => _setFilter(() => _tags = _toggled(_tags, t))),
                  onMetal: (m) => update(() => _setFilter(() => _metals = _toggled(_metals, m))),
                  onPriceRange: (r) => update(() => _setFilter(() {
                        _priceSlider = null; // a preset overrides the slider
                        _priceRange = _priceRange == r ? '' : r;
                      })),
                  onPriceSlider: (v) => update(() => _setFilter(() {
                        _priceRange = ''; // the slider overrides the presets
                        _priceSlider = v;
                      })),
                  onClearAll: () => update(_clearAll),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productListProvider);
    final rates = ref.watch(silverRatesValueProvider);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final count = state.items.length;

    final header = Container(
      width: double.infinity,
      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('THE COLLECTION',
              style: theme.textTheme.labelSmall?.copyWith(color: muted, letterSpacing: 2.4)),
          const SizedBox(height: 12),
          Text('Shop Silver',
              style: theme.textTheme.headlineLarge?.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: 8),
          Text('Explore our exquisite collection of handcrafted silver jewellery',
              style: TextStyle(color: muted, fontWeight: FontWeight.w300)),
        ],
      ),
    );

    final toolbar = Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Search products...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _openFilters,
                icon: const Icon(Icons.filter_list, size: 16),
                label: const Text('Filters'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<ProductSort>(
                  initialValue: _sort,
                  isDense: true,
                  decoration: const InputDecoration(isDense: true),
                  items: [
                    for (final s in ProductSort.values)
                      DropdownMenuItem(value: s, child: Text(s.label)),
                  ],
                  onChanged: (s) {
                    if (s == null) return;
                    setState(() => _sort = s);
                    _apply();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!state.isLoadingFirstPage)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Showing $count product${count != 1 ? 's' : ''}${state.hasMore && count > 0 ? '+' : ''}',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );

    final Widget body;
    if (state.isLoadingFirstPage) {
      body = SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 80),
          child: Column(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Loading products...', style: TextStyle(color: muted)),
            ],
          ),
        ),
      );
    } else if (state.error != null && state.items.isEmpty) {
      body = SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 32),
          child: Column(
            children: [
              Icon(Icons.cloud_off, size: 48, color: theme.colorScheme.outline),
              const SizedBox(height: 16),
              Text('Could not load products', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(state.error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.read(productListProvider.notifier).refresh(),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    } else if (state.items.isEmpty) {
      body = SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 16),
          child: Column(
            children: [
              Text('No products found matching your criteria.',
                  textAlign: TextAlign.center, style: TextStyle(color: muted)),
              TextButton(onPressed: _clearAll, child: const Text('Clear all filters')),
            ],
          ),
        ),
      );
    } else {
      body = SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            // Max extent rather than a fixed count so tablets get more columns.
            maxCrossAxisExtent: 240,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.62,
          ),
          itemCount: state.items.length,
          itemBuilder: (context, index) {
            final product = state.items[index];
            return ProductCard(
              product: product,
              rates: rates,
              onTap: () => context.push('/product/${product.id}'),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop'),
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final count = ref.watch(cartCountProvider);
              return Badge(
                isLabelVisible: count > 0,
                label: Text('$count'),
                child: IconButton(
                  icon: const Icon(Icons.shopping_bag_outlined),
                  tooltip: 'Cart',
                  onPressed: () => context.push('/cart'),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'My profile',
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(silverRatesProvider);
          await ref.read(productListProvider.notifier).refresh();
        },
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: header),
            SliverToBoxAdapter(child: toolbar),
            body,
            SliverToBoxAdapter(child: _buildFooter(state)),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(ProductListState state) {
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    if (state.error != null && state.items.isNotEmpty) {
      return Center(
        child: TextButton(
          onPressed: () => ref.read(productListProvider.notifier).loadMore(),
          child: const Text('Retry'),
        ),
      );
    }
    return const SizedBox(height: 24);
  }
}

/// The web's `FilterSidebar`. Changes apply immediately.
class _FilterPanel extends ConsumerWidget {
  const _FilterPanel({
    required this.categories,
    required this.subcategories,
    required this.tags,
    required this.metals,
    required this.priceRange,
    required this.priceSlider,
    required this.onCategory,
    required this.onSubcategory,
    required this.onTag,
    required this.onMetal,
    required this.onPriceRange,
    required this.onPriceSlider,
    required this.onClearAll,
  });

  final List<String> categories, subcategories, tags, metals;
  final String priceRange;
  final RangeValues? priceSlider;
  final ValueChanged<CategoryNode> onCategory;
  final ValueChanged<String> onSubcategory, onTag, onMetal, onPriceRange;
  final ValueChanged<RangeValues> onPriceSlider;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final allCategories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final allTags = ref.watch(tagsProvider).valueOrNull ?? const [];

    Widget heading(String t) => Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Text(t, style: theme.textTheme.titleLarge?.copyWith(fontSize: 18)),
        );
    Widget check(String label, bool value, VoidCallback onTap, {bool sub = false}) =>
        CheckboxListTile(
          value: value,
          onChanged: (_) => onTap(),
          dense: true,
          contentPadding: EdgeInsets.only(left: sub ? 24 : 0),
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(label, style: sub ? TextStyle(color: muted) : null),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading('Categories'),
        for (final c in allCategories) ...[
          check(c.name, categories.contains(c.name), () => onCategory(c)),
          for (final s in c.subcategories)
            check(s, subcategories.contains(s), () => onSubcategory(s), sub: true),
        ],
        const SizedBox(height: 16),
        heading('Price Range'),
        _PriceRangeFilter(value: priceSlider, onChange: onPriceSlider),
        Text('Or pick a range', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
        RadioGroup<String>(
          groupValue: priceRange,
          onChanged: (v) => onPriceRange(v ?? ''),
          child: Column(
            children: [
              for (final (label, value) in _priceRanges)
                RadioListTile<String>(
                  value: value,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  // Tapping the selected bucket again clears it.
                  toggleable: true,
                  title: Text(label),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        heading('Metal'),
        for (final m in _metals) check(m, metals.contains(m), () => onMetal(m)),
        if (allTags.isNotEmpty) ...[
          const SizedBox(height: 16),
          heading('Tags'),
          for (final t in allTags) check(t, tags.contains(t), () => onTag(t)),
        ],
        const SizedBox(height: 16),
        OutlinedButton(onPressed: onClearAll, child: const Text('Clear All Filters')),
      ],
    );
  }
}

/// Owns the live drag value; commits upward 700 ms after the last change.
class _PriceRangeFilter extends StatefulWidget {
  const _PriceRangeFilter({required this.value, required this.onChange});

  final RangeValues? value;
  final ValueChanged<RangeValues> onChange;

  @override
  State<_PriceRangeFilter> createState() => _PriceRangeFilterState();
}

class _PriceRangeFilterState extends State<_PriceRangeFilter> {
  late RangeValues _live = widget.value ?? const RangeValues(priceMin, priceMax);
  Timer? _timer;

  @override
  void didUpdateWidget(_PriceRangeFilter old) {
    super.didUpdateWidget(old);
    // Re-sync when the committed value changes from outside (preset, clear all).
    if (old.value != widget.value) _live = widget.value ?? const RangeValues(priceMin, priceMax);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bold = TextStyle(fontWeight: FontWeight.w500);
    return Column(
      children: [
        RangeSlider(
          values: _live,
          min: priceMin,
          max: priceMax,
          divisions: ((priceMax - priceMin) / 100).round(),
          semanticFormatterCallback: (v) => formatInr(v),
          onChanged: (v) {
            // minStepsBetweenThumbs = 1
            if (v.end - v.start < 100) return;
            setState(() => _live = v);
            _timer?.cancel();
            _timer = Timer(_priceDebounce, () => widget.onChange(v));
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formatInr(_live.start), style: bold),
              Text('${formatInr(_live.end)}${_live.end >= priceMax ? '+' : ''}', style: bold),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
