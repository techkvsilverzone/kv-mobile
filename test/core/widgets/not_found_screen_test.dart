import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kv_silver_mobile/core/widgets/not_found_screen.dart';

void main() {
  testWidgets('unknown route shows the 404 page and returns home', (tester) async {
    final router = GoRouter(
      initialLocation: '/nope',
      errorBuilder: (_, __) => const NotFoundScreen(),
      routes: [GoRoute(path: '/home', builder: (_, __) => const Text('home page'))],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Page not found'), findsOneWidget);

    await tester.tap(find.text('Go to Home'));
    await tester.pumpAndSettle();
    expect(find.text('home page'), findsOneWidget);
  });
}
