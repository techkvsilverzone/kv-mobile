import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/pricing/pricing.dart';
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

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(() => ref.read(productListProvider.notifier).refresh());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < _loadMoreExtent) {
      ref.read(productListProvider.notifier).loadMore();
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, () {
      final controller = ref.read(productListProvider.notifier);
      controller.applyFilters(
        value.trim().isEmpty
            ? controller.filters.copyWith(clearSearch: true)
            : controller.filters.copyWith(search: value.trim()),
      );
    });
  }

  Future<void> _openFilters() async {
    final controller = ref.read(productListProvider.notifier);
    final updated = await showModalBottomSheet<ProductFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FilterSheet(initial: controller.filters),
    );
    if (updated != null) await controller.applyFilters(updated);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productListProvider);
    final rates = ref.watch(silverRatesValueProvider);
    final filters = ref.read(productListProvider.notifier).filters;
    final activeFilterCount =
        filters.categories.length + filters.metals.length + (filters.minPrice != null ? 1 : 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'My profile',
            onPressed: () => context.push('/profile'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Search products',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                                setState(() {});
                              },
                            ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Badge(
                  isLabelVisible: activeFilterCount > 0,
                  label: Text('$activeFilterCount'),
                  child: IconButton.filledTonal(
                    icon: const Icon(Icons.tune),
                    tooltip: 'Filters',
                    onPressed: _openFilters,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(silverRatesProvider);
          await ref.read(productListProvider.notifier).refresh();
        },
        child: _buildBody(state, rates),
      ),
    );
  }

  Widget _buildBody(ProductListState state, List<MetalRate> rates) {
    if (state.isLoadingFirstPage) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.items.isEmpty) {
      return _CenteredMessage(
        icon: Icons.cloud_off,
        title: 'Could not load products',
        message: state.error!,
        actionLabel: 'Try again',
        onAction: () => ref.read(productListProvider.notifier).refresh(),
      );
    }

    if (state.items.isEmpty) {
      return _CenteredMessage(
        icon: Icons.search_off,
        title: 'No products found',
        message: 'No products match your search or filters.',
        actionLabel: 'Clear filters',
        onAction: () {
          _searchController.clear();
          ref.read(productListProvider.notifier).applyFilters(const ProductFilters());
        },
      );
    }

    return GridView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        // Max extent rather than a fixed count so tablets get more columns.
        maxCrossAxisExtent: 240,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.62,
      ),
      // One extra cell carries the trailing loader / end-of-list marker.
      itemCount: state.items.length + 1,
      itemBuilder: (context, index) {
        if (index == state.items.length) return _buildFooter(state);
        final product = state.items[index];
        return ProductCard(
          product: product,
          rates: rates,
          onTap: () => context.push('/product/${product.id}'),
        );
      },
    );
  }

  Widget _buildFooter(ProductListState state) {
    if (state.isLoadingMore) {
      return const Center(
        child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (state.error != null) {
      return Center(
        child: TextButton(
          onPressed: () => ref.read(productListProvider.notifier).loadMore(),
          child: const Text('Retry'),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({required this.initial});

  final ProductFilters initial;

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late final List<String> _categories = [...widget.initial.categories];
  late ProductSort _sort = widget.initial.sort;
  late RangeValues _price = RangeValues(
    widget.initial.minPrice ?? 0,
    widget.initial.maxPrice ?? 50000,
  );
  late bool _priceEnabled = widget.initial.minPrice != null || widget.initial.maxPrice != null;

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Filters', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Text('Category', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              categories.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (_, __) => const Text('Categories unavailable'),
                data: (list) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: list
                      .map((c) => FilterChip(
                            label: Text(c),
                            selected: _categories.contains(c),
                            onSelected: (on) => setState(() {
                              on ? _categories.add(c) : _categories.remove(c);
                            }),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 20),
              Text('Sort by', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ProductSort.values
                    .map((s) => ChoiceChip(
                          label: Text(s.label),
                          selected: _sort == s,
                          onSelected: (_) => setState(() => _sort = s),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text('Price range', style: Theme.of(context).textTheme.titleSmall),
                  const Spacer(),
                  Switch(
                    value: _priceEnabled,
                    onChanged: (v) => setState(() => _priceEnabled = v),
                  ),
                ],
              ),
              RangeSlider(
                values: _price,
                min: 0,
                max: 50000,
                divisions: 50,
                labels: RangeLabels('₹${_price.start.round()}', '₹${_price.end.round()}'),
                onChanged: _priceEnabled ? (v) => setState(() => _price = v) : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(
                        context,
                        // Preserve the active search; only filters reset here.
                        ProductFilters(search: widget.initial.search),
                      ),
                      child: const Text('Clear all'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(
                        context,
                        ProductFilters(
                          categories: _categories,
                          metals: widget.initial.metals,
                          minPrice: _priceEnabled ? _price.start : null,
                          maxPrice: _priceEnabled ? _price.end : null,
                          search: widget.initial.search,
                          sort: _sort,
                        ),
                      ),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 80),
        Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 16),
        Text(title,
            textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Center(child: FilledButton(onPressed: onAction, child: Text(actionLabel))),
      ],
    );
  }
}
