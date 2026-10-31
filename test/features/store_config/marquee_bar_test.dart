import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/core/pricing/pricing.dart';
import 'package:kv_silver_mobile/features/store_config/marquee_bar.dart';

MetalRate _r(String purity, double g, String date) =>
    MetalRate(id: date, date: date, ratePerGram: g, ratePerKg: g * 1000, purity: purity);

void main() {
  test('no rates: placeholder rate lines then fallback messages', () {
    final u = buildMarqueeUpdates(today: [], history: [], customMessages: ['  ']);
    expect(u.map((e) => e.text).take(2),
        ['Silver: Live rate update soon', 'Gold 22K: Live rate update soon']);
    expect(u.length, 5);
  });

  test('rates with trend vs the previous day, and custom messages replace fallbacks', () {
    final u = buildMarqueeUpdates(
      today: [_r('999', 95.5, '2026-10-31'), _r('916', 7000, '2026-10-31')],
      history: [_r('999', 95.5, '2026-10-31'), _r('999', 94, '2026-10-30'), _r('916', 7000, '2026-10-31')],
      customMessages: ['Diwali offer'],
    );
    expect(u[0].text, 'Silver: ₹95,500/kg  |  ₹95.5/g');
    expect(u[0].change, 1.5);
    expect(u[1].text, 'Gold 22K: ₹70,00,000/kg  |  ₹7,000/g');
    expect(u[1].change, 0);
    expect(u.last.text, 'Diwali offer');
    expect(u.length, 3);
  });
}
