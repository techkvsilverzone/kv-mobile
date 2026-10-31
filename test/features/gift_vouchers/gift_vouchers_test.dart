import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/features/cart/data/models/cart_item.dart';
import 'package:kv_silver_mobile/features/gift_vouchers/gift_vouchers_screen.dart';

void main() {
  test('vouchers: envelope or list, active only, stable by sortOrder, label fallback', () {
    final v = parseGiftVouchers({
      'status': 'success',
      'data': [
        {'_id': 'b', 'amount': 2000, 'sortOrder': 2},
        {'_id': 'a', 'label': 'Festive', 'amount': 1000, 'sortOrder': 1},
        {'_id': 'c', 'amount': 500, 'sortOrder': 1, 'isActive': false},
        {'_id': 'd', 'value': 750, 'sortOrder': 1},
      ],
    });
    expect(v.map((e) => e.id), ['a', 'd', 'b']);
    expect(v[2].name, '₹2,000 Gift Voucher');
    expect(parseGiftVouchers([{'id': 'x', 'price': 10}]).single.price, 10);
  });

  test('a voucher cart line is sent with isGiftVoucher and giftVoucherId', () {
    const item = CartItem(
        productId: 'gv1', name: 'GV', unitPrice: 1000, quantity: 2, inStock: true, stockAvailable: 0, isGiftVoucher: true);
    expect(item.toOrderLine(), {'product': 'gv1', 'quantity': 2, 'isGiftVoucher': true, 'giftVoucherId': 'gv1'});
    expect(CartItem.fromJson(item.toJson()).isGiftVoucher, isTrue);
  });
}
