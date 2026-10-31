import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api/api_client.dart';

/// `GET /store-config`: the admin-chosen theme, dark mode and marquee messages.
class StoreConfig {
  const StoreConfig({this.theme, this.isDark = false, this.marqueeMessages = const []});

  final String? theme;
  final bool isDark;
  final List<String> marqueeMessages;

  factory StoreConfig.fromJson(Map<String, dynamic> json) => StoreConfig(
        theme: json['theme'] as String?,
        isDark: json['isDark'] == true,
        marqueeMessages: (json['marqueeMessages'] as List? ?? const [])
            .map((e) => e.toString())
            .toList(growable: false),
      );

  Map<String, dynamic> toJson() =>
      {'theme': theme, 'isDark': isDark, 'marqueeMessages': marqueeMessages};
}

const _cacheKey = 'kv_silver_mobile.store_config';

/// Mirrors kv-ui/src/App.tsx `loadTheme`: fetch live, cache on success, fall back
/// to the cache when offline. `null` until either answers, which renders the
/// base (un-themed) palette, the same as the web before its fetch lands.
class StoreConfigController extends StateNotifier<StoreConfig?> {
  StoreConfigController(this._api) : super(null);

  final ApiClient _api;

  Future<void> load() async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      final data = await _api.get('/store-config');
      final config = StoreConfig.fromJson((data as Map).cast<String, dynamic>());
      state = config;
      await prefs.setString(_cacheKey, jsonEncode(config.toJson()));
    } catch (_) {
      try {
        final stored = prefs?.getString(_cacheKey);
        if (stored != null) {
          state = StoreConfig.fromJson((jsonDecode(stored) as Map).cast<String, dynamic>());
        }
      } catch (_) {/* malformed cache: keep the base palette */}
    }
  }
}

final storeConfigProvider = StateNotifierProvider<StoreConfigController, StoreConfig?>(
    (ref) => StoreConfigController(ref.watch(apiClientProvider)));
