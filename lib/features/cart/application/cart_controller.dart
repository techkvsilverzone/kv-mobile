import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../catalog/data/models/product.dart';
import '../data/cart_repository.dart';
import '../data/models/cart_item.dart';

const _cartStorageKey = 'kv_silver_mobile.cart';

/// The cart, held client-side and mirrored to the server on a best-effort basis.
///
/// Local storage is the source of truth because the server cart cannot express
/// a selected variant (see [CartItem]). Server writes are fire-and-forget: a
/// failed sync must never block adding to the cart or lose the local line.
class CartController extends StateNotifier<List<CartItem>> {
  CartController(this._repo) : super(const []);

  final CartRepository _repo;
  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs?.getString(_cartStorageKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      state = decoded
          .whereType<Map>()
          .map((e) => CartItem.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false);
    } catch (_) {
      // Corrupt cart — drop it rather than wedging the app on every launch.
      await _prefs?.remove(_cartStorageKey);
    }
  }

  Future<void> _persist() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setString(
      _cartStorageKey,
      jsonEncode(state.map((e) => e.toJson()).toList()),
    );
  }

  /// The server keys lines by product alone, so variants of one product are
  /// collapsed into a single summed quantity before syncing.
  void _syncProduct(String productId) {
    final total = state
        .where((e) => e.productId == productId)
        .fold<int>(0, (sum, e) => sum + e.quantity);

    Future(() async {
      try {
        if (total <= 0) {
          await _repo.removeItem(productId);
        } else {
          await _repo.putItem(productId: productId, quantity: total);
        }
      } catch (_) {
        // Ignored by design — the local cart already reflects the change.
      }
    });
  }

  void add(Product product, {required double unitPrice, ProductVariant? variant, int quantity = 1}) {
    final incoming = CartItem.fromProduct(
      product,
      unitPrice: unitPrice,
      quantity: quantity,
      variant: variant,
    );
    final existing = state.indexWhere((e) => e.lineKey == incoming.lineKey);

    if (existing >= 0) {
      final merged = [...state];
      merged[existing] = merged[existing].copyWith(
        quantity: merged[existing].quantity + quantity,
        // Refresh the price so a line added yesterday reflects today's rate.
        unitPrice: unitPrice,
      );
      state = merged;
    } else {
      state = [...state, incoming];
    }

    _persist();
    _syncProduct(product.id);
  }

  void setQuantity(String lineKey, int quantity) {
    final item = state.where((e) => e.lineKey == lineKey).firstOrNull;
    if (item == null) return;

    if (quantity <= 0) {
      remove(lineKey);
      return;
    }
    state = [
      for (final e in state) e.lineKey == lineKey ? e.copyWith(quantity: quantity) : e,
    ];
    _persist();
    _syncProduct(item.productId);
  }

  void remove(String lineKey) {
    final item = state.where((e) => e.lineKey == lineKey).firstOrNull;
    if (item == null) return;

    state = state.where((e) => e.lineKey != lineKey).toList(growable: false);
    _persist();
    _syncProduct(item.productId);
  }

  Future<void> clear() async {
    final productIds = state.map((e) => e.productId).toSet();
    state = const [];
    await _persist();
    for (final id in productIds) {
      Future(() async {
        try {
          await _repo.removeItem(id);
        } catch (_) {
          // Best effort.
        }
      });
    }
  }

  /// Refreshes stock flags and prices against the current catalogue. Called on
  /// entering checkout, because the web app never re-checks stock there and
  /// only discovers an out-of-stock item as a flattened create-order failure.
  void refreshAvailability(Map<String, Product> latest) {
    state = [
      for (final e in state)
        latest[e.productId] == null
            ? e
            : e.copyWith(
                inStock: latest[e.productId]!.inStock,
                stockAvailable: latest[e.productId]!.stockAvailable,
              ),
    ];
    _persist();
  }
}

final cartProvider = StateNotifierProvider<CartController, List<CartItem>>((ref) {
  return CartController(ref.watch(cartRepositoryProvider));
});

/// Total unit count, for the app-bar badge.
final cartCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).fold<int>(0, (sum, e) => sum + e.quantity);
});

/// Pre-GST subtotal. Display only — the server re-prices at checkout.
final cartSubtotalProvider = Provider<double>((ref) {
  return ref.watch(cartProvider).fold<double>(0, (sum, e) => sum + e.lineTotal);
});

final cartHasOutOfStockProvider = Provider<bool>((ref) {
  return ref.watch(cartProvider).any((e) => !e.inStock);
});
