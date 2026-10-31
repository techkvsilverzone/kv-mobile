import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/cart/application/cart_controller.dart';
import 'features/notifications/notifications.dart';
import 'features/notifications/push_service.dart';
import 'features/store_config/marquee_bar.dart';
import 'features/store_config/store_config.dart';

void main() {
  runApp(const ProviderScope(child: KvSilverMobileApp()));
}

class KvSilverMobileApp extends ConsumerStatefulWidget {
  const KvSilverMobileApp({super.key});

  @override
  ConsumerState<KvSilverMobileApp> createState() => _KvSilverMobileAppState();
}

class _KvSilverMobileAppState extends ConsumerState<KvSilverMobileApp> {
  // Pick up notifications that arrived while the app was in the background.
  late final AppLifecycleListener _lifecycle =
      AppLifecycleListener(onResume: () => ref.invalidate(notificationInboxProvider));

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Rehydrate the cart from local storage. It cannot come from the server:
    // the server cart drops the selected variant, so local storage is the only
    // place a "30 g" line survives a restart.
    Future.microtask(() => ref.read(cartProvider.notifier).load());
    _lifecycle;
    Future.microtask(() => ref.read(storeConfigProvider.notifier).load());
    Future.microtask(() => ref.read(pushServiceProvider).start(ref.read(appRouterProvider)));
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final config = ref.watch(storeConfigProvider);
    return MaterialApp.router(
      title: 'KV Silver Zone',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: AppTheme.build(themeKey: config?.theme, brightness: Brightness.light),
      darkTheme: AppTheme.build(themeKey: config?.theme, brightness: Brightness.dark),
      // The admin's isDark decides, not the phone setting, as on the web.
      themeMode: config?.isDark == true ? ThemeMode.dark : ThemeMode.light,
      // The web shows the marquee above the navbar on every customer page.
      builder: (context, child) => Column(
        children: [
          // Material: text above the Navigator needs one. The region sets the
          // status-bar icons for the marquee's colour, which now sits under them.
          AnnotatedRegion<SystemUiOverlayStyle>(
            value: ThemeData.estimateBrightnessForColor(Theme.of(context).colorScheme.primary) ==
                    Brightness.dark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
            child: Material(
              color: Theme.of(context).colorScheme.primary,
              child: const SafeArea(bottom: false, child: MarqueeBar()),
            ),
          ),
          Expanded(
            child: MediaQuery.removePadding(
                context: context, removeTop: true, child: child ?? const SizedBox()),
          ),
        ],
      ),
      routerConfig: router,
    );
  }
}
