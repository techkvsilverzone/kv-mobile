import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/features/recently_viewed/recently_viewed.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('newest first, de-duplicated, capped at 12, persisted', () async {
    SharedPreferences.setMockInitialValues({});
    final c = RecentlyViewedController();
    for (var i = 0; i < 14; i++) {
      await c.add('p$i');
    }
    await c.add('p5');
    expect(c.state.first, 'p5');
    expect(c.state.length, 12);
    expect(c.state.where((id) => id == 'p5').length, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('kv_silver_mobile.recently_viewed'), c.state);
    await c.clear();
    expect(c.state, isEmpty);
  });
}
