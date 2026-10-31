import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_session.dart';
import '../../core/ui/kv_ui.dart';

/// Product ids from `GET /wishlist`, which may be a bare list, `{items}` or
/// `{data}`, each item `{product: {...}}` (kv-ui services/wishlist.ts).
List<String> parseWishlistIds(dynamic raw) {
  final items = raw is List
      ? raw
      : raw is Map && raw['items'] is List
          ? raw['items'] as List
          : raw is Map && raw['data'] is List
              ? raw['data'] as List
              : const [];
  return [
    for (final i in items.whereType<Map>())
      if (i['product'] is Map)
        (i['product']['id'] ?? i['product']['_id'] ?? i['product']['imageId'] ?? '').toString()
  ].where((id) => id.isNotEmpty).toList();
}

class WishlistRepository {
  WishlistRepository(this._api);
  final ApiClient _api;

  Future<List<String>> fetchIds() async => parseWishlistIds(await _api.get('/wishlist'));
  Future<void> add(String productId) => _api.post('/wishlist/items', data: {'productId': productId});
  Future<void> remove(String productId) => _api.delete('/wishlist/items/$productId');
}

final wishlistRepositoryProvider =
    Provider<WishlistRepository>((ref) => WishlistRepository(ref.watch(apiClientProvider)));

/// Empty while signed out (the web only queries when authenticated).
final wishlistIdsProvider = FutureProvider<List<String>>((ref) async {
  if (!ref.watch(authSessionProvider).isAuthenticated) return const [];
  return ref.watch(wishlistRepositoryProvider).fetchIds();
});

/// The heart button's action on cards and the product page (kv-ui ProductCard).
Future<void> toggleWishlist(BuildContext context, WidgetRef ref,
    {required String productId, required String productName}) async {
  if (!ref.read(authSessionProvider).isAuthenticated) {
    showKvToast(context, 'Sign in to save favourites', error: true);
    context.push('/login');
    return;
  }
  final wishlisted = ref.read(wishlistIdsProvider).valueOrNull?.contains(productId) ?? false;
  try {
    final repo = ref.read(wishlistRepositoryProvider);
    wishlisted ? await repo.remove(productId) : await repo.add(productId);
    ref.invalidate(wishlistIdsProvider);
    if (context.mounted) {
      HapticFeedback.lightImpact();
      showKvToast(context, wishlisted ? 'Removed from wishlist' : 'Saved to wishlist',
          message: productName,
          actionLabel: wishlisted ? null : 'View',
          onAction: wishlisted ? null : () => context.push('/wishlist'));
    }
  } catch (_) {
    if (context.mounted) {
      showKvToast(context, "Couldn't update your wishlist", message: 'Please try again.', error: true);
    }
  }
}

/// Heart icon button bound to the wishlist.
class WishlistButton extends ConsumerStatefulWidget {
  const WishlistButton({super.key, required this.productId, required this.productName, this.size = 20});
  final String productId;
  final String productName;
  final double size;

  @override
  ConsumerState<WishlistButton> createState() => _WishlistButtonState();
}

class _WishlistButtonState extends ConsumerState<WishlistButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final on = ref.watch(wishlistIdsProvider).valueOrNull?.contains(widget.productId) ?? false;
    return IconButton(
      tooltip: on ? 'Remove from wishlist' : 'Add to wishlist',
      iconSize: widget.size,
      onPressed: _busy
          ? null
          : () async {
              setState(() => _busy = true);
              await toggleWishlist(context, ref, productId: widget.productId, productName: widget.productName);
              if (mounted) setState(() => _busy = false);
            },
      icon: Icon(on ? Icons.favorite : Icons.favorite_border, color: on ? Kv.danger : Kv.ink),
    );
  }
}
