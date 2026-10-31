// Screenshot harness for design review (not part of `flutter test`, which runs test/ only).
//   flutter test test_screens --update-goldens
// writes PNGs to test_screens/out/<name>.png at a phone size (393×852 logical, 2x).
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kv_silver_mobile/core/theme/app_theme.dart';

bool _fontsLoaded = false;

Future<void> loadAppFonts() async {
  if (_fontsLoaded) return;
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      final bytes = File(f).readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  await family('Inter', [
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) 'assets/fonts/Inter-$w.ttf',
  ]);
  await family('PlayfairDisplay', [
    for (final w in ['Regular', 'SemiBold', 'Bold', 'Italic']) 'assets/fonts/PlayfairDisplay-$w.ttf',
  ]);
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '/opt/homebrew/share/flutter';
  await family('MaterialIcons', ['$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
  _fontsLoaded = true;
}

/// Renders [screen] (inside the app theme and a router so `context.push` works)
/// and saves `test_screens/out/<name>.png`. Pass provider [overrides] with fake data.
/// Set [scroll] to drag the first scrollable by that many logical pixels first.
Future<void> screenshot(
  WidgetTester tester,
  String name,
  Widget screen, {
  List<Override> overrides = const [],
  double scroll = 0,
  Size size = const Size(393, 852),
  Future<void> Function(WidgetTester)? before,
}) async {
  await loadAppFonts();
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => screen),
    GoRoute(path: '/:rest(.*)', builder: (_, s) => Scaffold(body: Center(child: Text('→ ${s.uri}')))),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: overrides,
    child: MediaQuery(
      data: const MediaQueryData(size: Size(393, 852), devicePixelRatio: 2, padding: EdgeInsets.only(top: 24, bottom: 16), disableAnimations: true),
      child: MaterialApp.router(theme: AppTheme.light, debugShowCheckedModeBanner: false, routerConfig: router),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 500));
  if (before != null) await before(tester);
  await _precacheImages(tester);
  if (scroll != 0) {
    await tester.drag(find.byType(Scrollable).first, Offset(0, -scroll));
    await tester.pump(const Duration(milliseconds: 500));
  }
  await _precacheImages(tester);
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('out/$name.png'));
}

/// Asset images decode asynchronously; load them for real before capturing.
Future<void> _precacheImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final el in find.byType(Image).evaluate().toList()) {
      final provider = (el.widget as Image).image;
      if (provider is NetworkImage) continue; // no network in tests: placeholder shows
      try {
        await precacheImage(provider, el);
      } catch (_) {}
    }
  });
  await tester.pump(const Duration(milliseconds: 50));
}
