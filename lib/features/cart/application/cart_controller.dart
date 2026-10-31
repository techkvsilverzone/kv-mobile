import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../catalog/data/models/product.dart';
import '../../../core/auth/auth_session.dart';
import '../data/cart_repository.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../../core/pricing/pricing.dart';
import '../data/models/cart_item.dart';

const _cartStorageKey = 'kv_silver_mobile.cart';

/// The cart, held client-side and mirrored to the server on a best-effort basis.
///
/// Local storage is the source of truth because the server cart cannot express
/// a selected variant (see [CartItem]). Server writes are fire-and-forget: a
/// failed sync must never block adding to the cart or lose the local line.
class CartController extends StateNotifier<List<CartItem>> {
  CartController(this._repo, {bool Function()? isAuthenticated})
      : _isAuthenticated = isAuthenticated ?? (() => true),
        super(const []);

  final CartRepository _repo;

  /// A guest's cart lives on the phone only; the server cart needs a session.
  final bool Function() _isAuthenticated;

  /// On sign-in, copy the guest cart to the server cart (the web merges it too).
  void syncAll() {
    for (final id in state.map((e) => e.productId).toSet()) {
      _syncProduct(id);
    }
  }
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
    if (!_isAuthenticated()) return;
    if (state.any((e) => e.productId == productId && e.isGiftVoucher)) return;
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

  /// A gift voucher at its listed price (GST inclusive). Vouchers are not
  /// server-cart products, so they are never synced there.
  void addVoucher({required String id, required String name, required double price}) {
    final i = state.indexWhere((e) => e.isGiftVoucher && e.productId == id);
    if (i >= 0) {
      state = [for (final (j, e) in state.indexed) j == i ? e.copyWith(quantity: e.quantity + 1) : e];
    } else {
      state = [
        ...state,
        CartItem(
            productId: id, name: name, unitPrice: price, quantity: 1, inStock: true, stockAvailable: 0, isGiftVoucher: true),
      ];
    }
    _persist();
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

  /// Undo for [remove]: puts the exact line back at [index].
  void restore(CartItem item, int index) {
    if (state.any((e) => e.lineKey == item.lineKey)) return;
    state = [...state]..insert(index.clamp(0, state.length), item);
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

  /// Re-prices every product line (at its chosen size) and refreshes stock from the
  /// current catalogue, so the cart shows what checkout will charge. Vouchers keep
  /// their price.
  void refreshAvailability(Map<String, Product> latest) {
    state = [
      for (final e in state)
        if (e.isGiftVoucher || latest[e.productId] == null)
          e
        else
          e.copyWith(
            inStock: latest[e.productId]!.inStock,
            stockAvailable: latest[e.productId]!.stockAvailable,
            unitPrice: computeProductPricing(
              latest[e.productId]!.toPricingInput(),
              const [],
              gramsOverride: parseGrams(e.variantWeight),
            ).preGstPrice,
          ),
    ];
    _persist();
  }
}

/// Fetches the cart's products and re-prices the lines. Watched by the cart and
/// checkout screens, so prices are current whenever either opens.
final cartRefreshProvider = FutureProvider.autoDispose<void>((ref) async {
  final ids = ref.read(cartProvider).where((e) => !e.isGiftVoucher).map((e) => e.productId).toSet();
  if (ids.isEmpty) return;
  final repo = ref.read(catalogRepositoryProvider);
  final latest = <String, Product>{};
  await Future.wait(ids.map((id) async {
    try {
      latest[id] = await repo.fetchProduct(id);
    } catch (_) {/* keep the stored line if the product can't be fetched */}
  }));
  ref.read(cartProvider.notifier).refreshAvailability(latest);
});

final cartProvider = StateNotifierProvider<CartController, List<CartItem>>((ref) {
  final controller = CartController(ref.watch(cartRepositoryProvider),
      isAuthenticated: () => ref.read(authSessionProvider).isAuthenticated);
  ref.listen<AuthSessionState>(authSessionProvider, (prev, next) {
    if (next.isAuthenticated && !(prev?.isAuthenticated ?? false)) controller.syncAll();
  });
  return controller;
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
