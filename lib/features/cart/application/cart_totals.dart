import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../catalog/application/catalog_providers.dart';
import 'cart_controller.dart';

/// Pre-GST subtotal of GST-taxable lines only: gift vouchers are GST-inclusive
/// (kv-ui CartContext `taxableTotal`).
final cartTaxableSubtotalProvider = Provider<double>((ref) => ref
    .watch(cartProvider)
    .where((e) => !e.isGiftVoucher)
    .fold<double>(0, (sum, e) => sum + e.lineTotal));

/// GST percent from `/pricing-config`; the server default (3) until it loads.
final cartGstPercentProvider =
    Provider<double>((ref) => ref.watch(gstPercentProvider).valueOrNull ?? 3);

/// Display-only GST on the taxable lines (`taxAmount`). The server prices the
/// charged amount at checkout.
final cartGstProvider = Provider<double>(
    (ref) => ref.watch(cartTaxableSubtotalProvider) * ref.watch(cartGstPercentProvider) / 100);

/// shortcut: mirrors the server's flat GIFT_WRAP_FEE (kv-api pricing.service.ts) for the cart
/// estimate; checkout shows and charges the server's own figure. Move both to config together.
const giftWrapFee = 99.0;

/// The cart's gift-wrap choice, sent to checkout (`giftWrap` / `giftMessage`).
class GiftWrap {
  const GiftWrap({this.enabled = false, this.message = ''});
  final bool enabled;
  final String message;
}

final giftWrapProvider = StateProvider<GiftWrap>((ref) => const GiftWrap());
