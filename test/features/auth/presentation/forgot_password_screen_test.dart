import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kv_silver_mobile/core/api/api_exception.dart';
import 'package:kv_silver_mobile/features/auth/data/auth_repository.dart';
import 'package:kv_silver_mobile/features/auth/presentation/forgot_password_screen.dart';
import '../../../support/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repo;
  setUp(() => repo = FakeAuthRepository());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(initialLocation: '/forgot-password', routes: [
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: '/login', builder: (_, __) => const Scaffold(body: Text('LOGIN PAGE'))),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> sendCode(WidgetTester tester) async {
    await tester.enterText(find.widgetWithText(TextFormField, 'Email address'), ' asha@example.com ');
    await tester.tap(find.widgetWithText(FilledButton, 'Send reset code'));
    await tester.pumpAndSettle();
  }

  testWidgets('sends a code, then resets with code + new password and returns to login', (tester) async {
    await pump(tester);
    await sendCode(tester);
    expect(repo.forgotPasswordCalls, ['asha@example.com']);
    expect(find.text('Reset code'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Reset code'), '123456');
    await tester.enterText(find.widgetWithText(TextFormField, 'New password'), 'newpass1');
    await tester.enterText(find.widgetWithText(TextFormField, 'Confirm new password'), 'newpass1');
    await tester.tap(find.widgetWithText(FilledButton, 'Reset password'));
    await tester.pumpAndSettle();

    expect(repo.resetPasswordCalls, [('asha@example.com', '123456', 'newpass1')]);
    expect(find.text('LOGIN PAGE'), findsOneWidget);
  });

  testWidgets('validates the code and matching passwords, and shows the server error', (tester) async {
    await pump(tester);
    await sendCode(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Reset password'));
    await tester.pumpAndSettle();
    expect(find.text('Enter the 6-digit code'), findsOneWidget);
    expect(repo.resetPasswordCalls, isEmpty);

    repo.resetPasswordError = const ServerException(400, 'Incorrect code.');
    await tester.enterText(find.widgetWithText(TextFormField, 'Reset code'), '999999');
    await tester.enterText(find.widgetWithText(TextFormField, 'New password'), 'newpass1');
    await tester.enterText(find.widgetWithText(TextFormField, 'Confirm new password'), 'other');
    await tester.tap(find.widgetWithText(FilledButton, 'Reset password'));
    await tester.pumpAndSettle();
    expect(find.text('Passwords do not match'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Confirm new password'), 'newpass1');
    await tester.tap(find.widgetWithText(FilledButton, 'Reset password'));
    await tester.pumpAndSettle();
    expect(find.text('Incorrect code.'), findsOneWidget);
    expect(find.text('LOGIN PAGE'), findsNothing);
  });
}
