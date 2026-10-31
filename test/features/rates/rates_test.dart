import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/core/pricing/pricing.dart';
import 'package:kv_silver_mobile/features/rates/metal_key.dart';
import 'package:kv_silver_mobile/features/rates/presentation/rates_screen.dart';

MetalRate _r(String purity, double g, String date) =>
    MetalRate(id: date, date: date, ratePerGram: g, ratePerKg: g * 1000, purity: purity);

void main() {
  test('history groups by day, newest first, and ignores unknown metals', () {
    final rows = groupRateHistory([
      _r('999', 94, '2026-10-30T00:00:00Z'),
      _r('916', 7000, '2026-10-31'),
      _r('999', 95, '2026-10-31'),
      _r('platinum', 1, '2026-10-31'),
    ]);
    expect(rows.map((r) => r.day), ['2026-10-31', '2026-10-30']);
    expect(rows[0].silver, 95);
    expect(rows[0].gold, 7000);
    expect(rows[1].gold, isNull);
  });

  test('change is today minus the second-newest history row', () {
    final today = [_r(' Silver ', 95, '2026-10-31')];
    final history = [_r('999', 95, '2026-10-31'), _r('999', 96.5, '2026-10-30')];
    expect(MetalKey.silver.change(today, history), -1.5);
    expect(MetalKey.gold22k.change(today, history), 0);
  });
}
