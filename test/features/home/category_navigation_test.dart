import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Guards the home-tile → shop hand-off. Category names contain spaces and `+`
/// ("Wood + Silver", "Silver coin + Box"); if either is mangled in the URL, the
/// shop opens filtered to a category that matches nothing.
void main() {
  test('category round-trips through a query component unchanged', () {
    for (final category in const [
      'Wood + Silver',
      'Silver coin + Box',
      '999 Silver',
      'Paper / Board',
    ]) {
      final encoded = Uri.encodeQueryComponent(category);
      final parsed = Uri.parse('/shop?category=$encoded').queryParameters['category'];
      expect(parsed, category, reason: category);
    }
  });

  testWidgets('the shop route decodes the category into an initial filter',
      (tester) async {
    String? seenCategory;

    final router = GoRouter(
      initialLocation:
          '/shop?category=${Uri.encodeQueryComponent('Wood + Silver')}',
      routes: [
        GoRoute(
          path: '/shop',
          builder: (context, state) {
            seenCategory = state.uri.queryParameters['category'];
            return const Scaffold(body: Text('shop'));
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(seenCategory, 'Wood + Silver');
  });
}
