import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/format/currency.dart';
import '../../../core/ui/kv_ui.dart';
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

// kv-ui Shop.tsx price slider: fixed ₹100–₹5,000, step 100.
const priceMin = 100.0;
const priceMax = 5000.0;

const _metalOptions = ['Silver', 'Gold 22K'];
const _priceRanges = [
  ('Under ₹500', '0-500'),
  ('₹500 – ₹1,000', '500-1000'),
  ('₹1,000 – ₹2,000', '1000-2000'),
  ('Above ₹5,000', '5000+'),
];

/// Web `getPriceBounds` for a preset bucket ("500-1000", "5000+").
(double?, double?) priceBounds(String range) {
  if (range.isEmpty) return (null, null);
  if (range.endsWith('+')) return (double.tryParse(range.replaceAll('+', '')), null);
  final parts = range.split('-');
  return (double.tryParse(parts.first), parts.length > 1 ? double.tryParse(parts[1]) : null);
}

/// Everything the filter sheet edits. The sheet works on a copy and commits on Apply.
class _Filters {
  const _Filters({
    this.categories = const [],
    this.subcategories = const [],
    this.tags = const [],
    this.metals = const [],
    this.priceRange = '',
    this.priceSlider,
  });

  final List<String> categories, subcategories, tags, metals;
  final String priceRange;
  final RangeValues? priceSlider;

  int get count =>
      categories.length +
      subcategories.length +
      tags.length +
      metals.length +
      (priceRange.isNotEmpty || priceSlider != null ? 1 : 0);

  _Filters copyWith({
    List<String>? categories,
    List<String>? subcategories,
    List<String>? tags,
    List<String>? metals,
    String? priceRange,
    RangeValues? priceSlider,
    bool clearSlider = false,
  }) =>
      _Filters(
        categories: categories ?? this.categories,
        subcategories: subcategories ?? this.subcategories,
        tags: tags ?? this.tags,
        metals: metals ?? this.metals,
        priceRange: priceRange ?? this.priceRange,
        priceSlider: clearSlider ? null : (priceSlider ?? this.priceSlider),
      );
}

List<String> _toggled(List<String> list, String v) => list.contains(v) ? (List.of(list)..remove(v)) : [...list, v];

/// Shop tab (kv-ui pages/Shop.tsx): search, category chips, filter + sort
/// sheets, result count, infinite-scroll grid.
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
  final _searchFocus = FocusNode();
  late final _searchController = TextEditingController(text: widget.initialSearch ?? '');
  Timer? _debounce;
  Uri? _handledUri;

  _Filters _f = const _Filters();
  ProductSort _sort = ProductSort.newest;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    final category = widget.initialCategory;
    if (category != null && category.isNotEmpty) _f = _Filters(categories: [category]);
    Future.microtask(_apply);
  }

  @override
  void didUpdateWidget(ShopScreen old) {
    super.didUpdateWidget(old);
    // The tab keeps this state alive, so a later `/shop?category=` or `?search=` arrives here.
    final category = widget.initialCategory;
    if (category != old.initialCategory && category != null && category.isNotEmpty) {
      _commit(_Filters(categories: [category]));
    } else if (widget.initialSearch != old.initialSearch && (widget.initialSearch ?? '').isNotEmpty) {
      _searchController.text = widget.initialSearch!;
      _onSearchChanged(widget.initialSearch!);
    }
  }

  /// `?focus=search` (Home's search bar) focuses the field once per navigation.
  void _handleFocusParam() {
    if (GoRouter.maybeOf(context) == null) return;
    final uri = GoRouterState.of(context).uri;
    if (uri == _handledUri) return;
    _handledUri = uri;
    if (uri.queryParameters['focus'] == 'search') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  ProductFilters get _filters {
    // The slider (when set) overrides the presets; a handle at an extreme means
    // "no cap" on that end.
    final slider = _f.priceSlider;
    final (min, max) = slider != null
        ? (slider.start > priceMin ? slider.start : null, slider.end < priceMax ? slider.end : null)
        : priceBounds(_f.priceRange);
    final search = _searchController.text.trim();
    return ProductFilters(
      categories: _f.categories,
      subcategories: _f.subcategories,
      tags: _f.tags,
      metals: _f.metals,
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
  void _commit(_Filters f) {
    _debounce?.cancel();
    _searchController.clear();
    setState(() => _f = f);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    _apply();
  }

  void _clearAll() => _commit(const _Filters());

  /// Typing a search clears every filter.
  void _onSearchChanged(String value) {
    setState(() => _f = const _Filters());
    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, _apply);
  }

  void _toggleCategory(CategoryNode c) => _commit(_f.copyWith(
        categories: _toggled(_f.categories, c.name),
        // Deselecting a category drops its selected subcategories.
        subcategories: _f.categories.contains(c.name)
            ? _f.subcategories.where((s) => !c.subcategories.contains(s)).toList()
            : null,
      ));

  Future<void> _openFilters() async {
    final result = await showKvSheet<_Filters>(
      context,
      title: 'Filters',
      builder: (_) => _FilterSheet(initial: _f),
    );
    if (result != null) _commit(result);
  }

  Future<void> _openSort() async {
    final picked = await showKvSheet<ProductSort>(
      context,
      title: 'Sort by',
      builder: (ctx) => ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 16), children: [
        for (final s in ProductSort.values)
          ListTile(
            title: Text(s.label,
                style: TextStyle(fontWeight: s == _sort ? FontWeight.w600 : FontWeight.w400, color: Kv.ink)),
            trailing: s == _sort ? const Icon(Icons.check_rounded, color: Kv.blue) : null,
            onTap: () => Navigator.pop(ctx, s),
          ),
      ]),
    );
    if (picked == null || picked == _sort) return;
    setState(() => _sort = picked);
    _apply();
  }

  @override
  Widget build(BuildContext context) {
    _handleFocusParam();
    final state = ref.watch(productListProvider);
    final rates = ref.watch(silverRatesValueProvider);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const <CategoryNode>[];
    final count = state.items.length;
    final hasQuery = _f.count > 0 || _searchController.text.isNotEmpty;

    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 600 ? 3 : 2;
    final cell = (width - Kv.pad * 2 - 12 * (columns - 1)) / columns;

    final Widget body;
    if (state.isLoadingFirstPage) {
      body = const SliverToBoxAdapter(child: ProductGridSkeleton(count: 6));
    } else if (state.error != null && state.items.isEmpty) {
      body = SliverToBoxAdapter(
        child: EmptyState(
          icon: Icons.cloud_off_rounded,
          title: "Couldn't load products",
          message: 'Check your connection and try again.',
          actionLabel: 'Try again',
          onAction: () => ref.read(productListProvider.notifier).refresh(),
        ),
      );
    } else if (state.items.isEmpty) {
      body = SliverToBoxAdapter(
        child: EmptyState(
          icon: Icons.search_off_rounded,
          title: 'No matching pieces',
          message: hasQuery ? 'Try a different search or fewer filters.' : 'New pieces are added every week.',
          actionLabel: hasQuery ? 'Clear filters' : null,
          onAction: _clearAll,
        ),
      );
    } else {
      body = SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: Kv.pad),
        sliver: SliverGrid.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 20,
            crossAxisSpacing: 12,
            mainAxisExtent: cell + productCardInfoHeight,
          ),
          itemCount: state.items.length,
          itemBuilder: (context, i) {
            final product = state.items[i];
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
      backgroundColor: Kv.surface,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(silverRatesProvider);
          await ref.read(productListProvider.notifier).refresh();
        },
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverAppBar(
              pinned: true,
              titleSpacing: Kv.pad,
              title: const Text('Shop', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Kv.ink)),
              actions: [
                IconButton(
                  tooltip: 'Wishlist',
                  onPressed: () => context.push('/wishlist'),
                  icon: const Icon(Icons.favorite_border_rounded),
                ),
                const SizedBox(width: 4),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(112),
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Kv.pad, 4, Kv.pad, 8),
                    child: _SearchField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      onChanged: _onSearchChanged,
                      onClear: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    ),
                  ),
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(Kv.pad, 4, Kv.pad, 8),
                      children: [
                        _ToolChip(
                          icon: Icons.tune_rounded,
                          label: _f.count > 0 ? 'Filters · ${_f.count}' : 'Filters',
                          active: _f.count > 0,
                          onTap: _openFilters,
                        ),
                        const SizedBox(width: 8),
                        _ToolChip(
                          icon: Icons.swap_vert_rounded,
                          label: _sort == ProductSort.newest ? 'Sort' : _sort.label,
                          active: _sort != ProductSort.newest,
                          onTap: _openSort,
                        ),
                        Container(
                          width: 1,
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          color: Kv.line,
                        ),
                        _ToolChip(label: 'All', active: _f.categories.isEmpty, onTap: () {
                          if (_f.categories.isNotEmpty) _commit(_f.copyWith(categories: [], subcategories: []));
                        }),
                        for (final c in categories) ...[
                          const SizedBox(width: 8),
                          _ToolChip(label: c.name, active: _f.categories.contains(c.name), onTap: () => _toggleCategory(c)),
                        ],
                      ],
                    ),
                  ),
                ]),
              ),
            ),
            const SliverToBoxAdapter(child: Divider()),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 48,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Kv.pad, 0, 4, 0),
                  child: Row(children: [
                    Expanded(
                      child: state.isLoadingFirstPage
                          ? const SizedBox.shrink()
                          : Text(
                              '$count${state.hasMore && count > 0 ? '+' : ''} product${count != 1 ? 's' : ''}',
                              style: const TextStyle(fontSize: 13, color: Kv.muted, fontWeight: FontWeight.w500),
                            ),
                    ),
                    if (hasQuery)
                      TextButton(onPressed: _clearAll, child: const Text('Clear all')),
                  ]),
                ),
              ),
            ),
            body,
            SliverToBoxAdapter(child: _buildFooter(state)),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(ProductListState state) {
    if (state.isLoadingMore) {
      return const Padding(padding: EdgeInsets.only(top: 20, bottom: 24), child: ProductGridSkeleton(count: 2));
    }
    if (state.error != null && state.items.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: TextButton.icon(
            onPressed: () => ref.read(productListProvider.notifier).loadMore(),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text("Couldn't load more · Retry"),
          ),
        ),
      );
    }
    return const SizedBox(height: 32);
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.focusNode, required this.onChanged, required this.onClear});

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(borderRadius: Kv.smallRadius, borderSide: BorderSide.none);
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: Kv.bg,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          hintText: 'Search anklets, coins, pooja items…',
          prefixIcon: const Icon(Icons.search_rounded, color: Kv.muted),
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(tooltip: 'Clear search', onPressed: onClear, icon: const Icon(Icons.close_rounded, size: 20)),
          border: border,
          enabledBorder: border,
          focusedBorder: OutlineInputBorder(borderRadius: Kv.smallRadius, borderSide: const BorderSide(color: Kv.blue)),
        ),
      ),
    );
  }
}

/// Pill used for the toolbar (Filters, Sort) and category quick-filters.
class _ToolChip extends StatelessWidget {
  const _ToolChip({required this.label, required this.active, required this.onTap, this.icon});

  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: active,
        button: true,
        child: Material(
          color: active ? Kv.ink : Kv.surface,
          shape: StadiumBorder(side: BorderSide(color: active ? Kv.ink : Kv.line)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.fromLTRB(icon == null ? 14 : 10, 0, 14, 0),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) ...[Icon(icon, size: 17, color: active ? Colors.white : Kv.ink), const SizedBox(width: 6)],
                Text(label,
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: active ? Colors.white : Kv.ink)),
              ]),
            ),
          ),
        ),
      );
}

/// The web's `FilterSidebar`, as a sheet with a draft copy. Pops the new filters on Apply.
class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({required this.initial});
  final _Filters initial;

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late _Filters _d = widget.initial;

  @override
  Widget build(BuildContext context) {
    final allCategories = ref.watch(categoriesProvider).valueOrNull ?? const <CategoryNode>[];
    final allTags = ref.watch(tagsProvider).valueOrNull ?? const <String>[];
    final subs = [
      for (final c in allCategories)
        if (_d.categories.contains(c.name)) ...c.subcategories,
    ];
    final slider = _d.priceSlider ?? const RangeValues(priceMin, priceMax);

    Widget section(String title, List<Widget> children) => Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (title.isNotEmpty) ...[
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
            ],
            Wrap(spacing: 8, runSpacing: 8, children: children),
          ]),
        );
    Widget chip(String label, bool on, VoidCallback onTap) =>
        FilterChip(label: Text(label), selected: on, onSelected: (_) => onTap());

    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Flexible(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 4, 20, 4), children: [
          if (allCategories.isNotEmpty)
            section('Category', [
              for (final c in allCategories)
                chip(c.name, _d.categories.contains(c.name), () => setState(() {
                      final on = _d.categories.contains(c.name);
                      _d = _d.copyWith(
                        categories: _toggled(_d.categories, c.name),
                        subcategories: on ? _d.subcategories.where((s) => !c.subcategories.contains(s)).toList() : null,
                      );
                    })),
            ]),
          if (subs.isNotEmpty)
            section('Type', [
              for (final s in subs)
                chip(s, _d.subcategories.contains(s),
                    () => setState(() => _d = _d.copyWith(subcategories: _toggled(_d.subcategories, s)))),
            ]),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              const Expanded(child: Text('Price', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
              Text(
                '${formatInr(slider.start)} – ${formatInr(slider.end)}${slider.end >= priceMax ? '+' : ''}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Kv.muted),
              ),
            ]),
          ),
          RangeSlider(
            values: slider,
            min: priceMin,
            max: priceMax,
            divisions: ((priceMax - priceMin) / 100).round(),
            semanticFormatterCallback: (v) => formatInr(v),
            onChanged: (v) {
              if (v.end - v.start < 100) return; // minStepsBetweenThumbs = 1
              // The slider overrides the presets.
              setState(() => _d = _d.copyWith(priceRange: '', priceSlider: v));
            },
          ),
          section('', [
            for (final (label, value) in _priceRanges)
              chip(label, _d.priceRange == value, () => setState(() {
                    // A preset overrides the slider; tapping it again clears it.
                    _d = _d.copyWith(priceRange: _d.priceRange == value ? '' : value, clearSlider: true);
                  })),
          ]),
          section('Metal', [
            for (final m in _metalOptions)
              chip(m, _d.metals.contains(m), () => setState(() => _d = _d.copyWith(metals: _toggled(_d.metals, m)))),
          ]),
          if (allTags.isNotEmpty)
            section('Tags', [
              for (final t in allTags)
                chip(t, _d.tags.contains(t), () => setState(() => _d = _d.copyWith(tags: _toggled(_d.tags, t)))),
            ]),
        ]),
      ),
      Container(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Kv.line))),
        padding: EdgeInsets.fromLTRB(Kv.pad, 12, Kv.pad, 12 + MediaQuery.paddingOf(context).bottom),
        child: Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _d.count == 0 ? null : () => setState(() => _d = const _Filters()),
              child: const Text('Clear'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, _d),
              child: Text(_d.count == 0 ? 'Show all' : 'Apply · ${_d.count}'),
            ),
          ),
        ]),
      ),
    ]);
  }
}
