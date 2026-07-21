import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../catalog/application/catalog_providers.dart';

/// Horizontal strip of category tiles.
///
/// Unlike the web — which hardcodes three "occasion" tiles with fragile query
/// strings ("Wood + Silver") that can silently stop matching — these come from
/// the live `/products/categories` endpoint, so every tile is guaranteed to
/// return products. Tapping opens the shop pre-filtered to that category.
class CategoryTiles extends ConsumerWidget {
  const CategoryTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);

    return categories.when(
      loading: () => const SizedBox(
        height: 108,
        child: Center(child: CircularProgressIndicator()),
      ),
      // A category outage should not blank the home screen — just drop the row.
      error: (_, __) => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => _CategoryTile(category: list[i]),
          ),
        );
      },
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});

  final String category;

  static const _icons = <String, IconData>{
    'Silver': Icons.diamond_outlined,
    '999 Silver': Icons.workspace_premium_outlined,
    'Silver plated': Icons.auto_awesome_outlined,
    'Silver coin + Box': Icons.paid_outlined,
    'Wood + Silver': Icons.temple_hindu_outlined,
    'Paper / Board': Icons.card_giftcard_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = _icons[category] ?? Icons.category_outlined;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      // Uri.encodeComponent keeps '+' and spaces intact through the route.
      onTap: () => context.push('/shop?category=${Uri.encodeQueryComponent(category)}'),
      child: SizedBox(
        width: 92,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 56,
              width: 56,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 8),
            Text(
              category,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
