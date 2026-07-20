import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/cart/application/cart_controller.dart';

void main() {
  runApp(const ProviderScope(child: KvSilverMobileApp()));
}

class KvSilverMobileApp extends ConsumerStatefulWidget {
  const KvSilverMobileApp({super.key});

  @override
  ConsumerState<KvSilverMobileApp> createState() => _KvSilverMobileAppState();
}

class _KvSilverMobileAppState extends ConsumerState<KvSilverMobileApp> {
  @override
  void initState() {
    super.initState();
    // Rehydrate the cart from local storage. It cannot come from the server:
    // the server cart drops the selected variant, so local storage is the only
    // place a "30 g" line survives a restart.
    Future.microtask(() => ref.read(cartProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'KV Silver Zone',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
