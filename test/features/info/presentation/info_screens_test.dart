import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/features/info/presentation/about_screen.dart';
import 'package:kv_silver_mobile/features/info/presentation/faq_screen.dart';
import 'package:kv_silver_mobile/features/info/presentation/privacy_policy_screen.dart';
import 'package:kv_silver_mobile/features/info/presentation/terms_screen.dart';

void main() {
  final screens = <String, Widget>{
    'About us': const AboutScreen(),
    'FAQ': const FaqScreen(),
    'Privacy policy': const PrivacyPolicyScreen(),
    'Terms & conditions': const TermsScreen(),
  };

  for (final MapEntry(key: title, value: screen) in screens.entries) {
    testWidgets('$title renders with its app bar title', (tester) async {
      await tester.pumpWidget(MaterialApp(home: screen));

      expect(find.descendant(of: find.byType(AppBar), matching: find.text(title)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('FAQ shows one category at a time and expands an answer', (tester) async {
    // Tall enough that the lazily built list has every question laid out.
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: FaqScreen()));
    expect(find.text('What is BIS Hallmarking?'), findsOneWidget);
    expect(find.text('Can I withdraw before the scheme matures?'), findsNothing);

    final chip = find.widgetWithText(ChoiceChip, 'Savings Scheme');
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(find.text('What is BIS Hallmarking?'), findsNothing);

    final question = find.text('Can I withdraw before the scheme matures?');
    await tester.ensureVisible(question);
    await tester.tap(question);
    await tester.pumpAndSettle();
    expect(find.textContaining('the bonus installment will be forfeited'), findsOneWidget);
  });
}
