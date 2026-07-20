import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import 'models/cart_item.dart';

/// Server-side cart sync.
///
/// Deliberately thin: the server cart holds only `{productId, quantity}` and
/// recomputes weight/price from the base product, so it cannot round-trip a
/// selected variant. It is used as a best-effort backup, never as the source of
/// truth — see [CartItem].
class CartRepository {
  CartRepository(this._api);

  final ApiClient _api;

  /// Upsert. Sending `quantity: 0` removes the line server-side.
  Future<void> putItem({required String productId, required int quantity}) async {
    await _api.post('/cart/items', data: {'productId': productId, 'quantity': quantity});
  }

  /// The path segment is the **productId**, not a line id.
  Future<void> removeItem(String productId) => _api.delete('/cart/items/$productId');

  /// Returns raw `{productId, quantity}` pairs. `productId` is a populated
  /// product object on GET but a bare id string after a write, so both shapes
  /// are flattened to an id here.
  Future<List<({String productId, int quantity})>> fetchItems() async {
    final data = await _api.get('/cart');
    final items = data is Map ? data['items'] : null;
    if (items is! List) return const [];

    return items.whereType<Map>().map((raw) {
      final ref = raw['productId'];
      final id = ref is Map ? (ref['_id'] ?? ref['id'] ?? '').toString() : ref.toString();
      return (productId: id, quantity: (raw['quantity'] as num?)?.toInt() ?? 1);
    }).where((e) => e.productId.isNotEmpty).toList(growable: false);
  }
}

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return CartRepository(ref.watch(apiClientProvider));
});
