import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'kv_silver_mobile.recently_viewed';
const _max = 12;

/// Product ids viewed on this phone, newest first, at most 12 (kv-ui
/// useRecentlyViewed: `localStorage['kv-recently-viewed']`).
class RecentlyViewedController extends StateNotifier<List<String>> {
  RecentlyViewedController() : super(const []) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getStringList(_key) ?? const [];
    } catch (_) {/* storage unavailable: start empty */}
  }

  Future<void> add(String productId) async {
    state = [productId, ...state.where((id) => id != productId)].take(_max).toList();
    try {
      await (await SharedPreferences.getInstance()).setStringList(_key, state);
    } catch (_) {/* ignore storage errors, like the web */}
  }

  Future<void> clear() async {
    state = const [];
    try {
      await (await SharedPreferences.getInstance()).remove(_key);
    } catch (_) {}
  }
}

final recentlyViewedProvider =
    StateNotifierProvider<RecentlyViewedController, List<String>>((ref) => RecentlyViewedController());
