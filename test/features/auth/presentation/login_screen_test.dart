import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/core/api/api_exception.dart';
import 'package:kv_silver_mobile/core/auth/auth_session.dart';
import 'package:kv_silver_mobile/core/storage/secure_token_storage.dart';
import 'package:kv_silver_mobile/features/auth/data/auth_repository.dart';
import 'package:kv_silver_mobile/core/router/app_router.dart';
import 'package:kv_silver_mobile/main.dart';
import 'package:kv_silver_mobile/app/splash_screen.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_secure_storage_client.dart';

void main() {
  late FakeAuthRepository repo;

  setUp(() => repo = FakeAuthRepository());

  ProviderContainer? lastContainer;

  Future<void> pumpApp(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        splashAnimatedProvider.overrideWithValue(false),
        secureTokenStorageProvider.overrideWithValue(SecureTokenStorage(FakeSecureStorageClient())),
        authRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    // Room for the marquee strip above every screen.
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const KvSilverMobileApp()),
    );
    await tester.pumpAndSettle();
    lastContainer = container;
    // Guests land on home; these flows start from the login screen.
    container.read(appRouterProvider).go('/login');
    await tester.pumpAndSettle();
  }

  Future<void> requestCodeFor(WidgetTester tester, String phone) async {
    // Mobile + OTP is the default tab, as on the web.
    await tester.enterText(find.widgetWithText(TextFormField, 'Mobile number'), phone);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Send login code'));
    await tester.pumpAndSettle();
  }

  testWidgets('login code is requested by mobile number, normalized to 10 digits', (tester) async {
    await pumpApp(tester);

    await requestCodeFor(tester, '+91 81908 58375');

    expect(repo.lastOtpPhone, '8190858375');
    expect(find.text('Sent to +91 8190858375'), findsOneWidget);
    expect(find.text('Code sent'), findsOneWidget);
  });

  testWidgets('an unregistered number shows the sign-up message and pre-fills signup', (tester) async {
    repo.requestOtpError =
        const ServerException(404, 'This mobile number is not registered. Please sign up first.');
    await pumpApp(tester);

    await requestCodeFor(tester, '9000000001');

    expect(find.text('Number not registered'), findsOneWidget);
    expect(find.text('This mobile number is not registered. Please sign up first.'), findsOneWidget);

    // The toast's Sign up action, as on the web.
    await tester.tap(find.widgetWithText(SnackBarAction, 'Sign up'));
    await tester.pumpAndSettle();

    expect(find.text('Join KV Silver Zone for exclusive offers.'), findsOneWidget);
    final phoneField = tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Mobile number'));
    expect(phoneField.controller!.text, '9000000001');
  });

  testWidgets('signup requires a mobile number and sends it normalized', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Create account'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Full name'), 'Vino');
    await tester.enterText(find.widgetWithText(TextFormField, 'Email address'), 'vino@example.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret1');
    await tester.enterText(find.widgetWithText(TextFormField, 'Confirm password'), 'secret1');
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    final submit = find.widgetWithText(FilledButton, 'Create account');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('Phone number is required'), findsOneWidget);
    expect(repo.lastSignupPhone, isNull);

    await tester.enterText(find.widgetWithText(TextFormField, 'Mobile number'), '081908 58375');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(repo.lastSignupPhone, '8190858375');
  });

  testWidgets('signing in on a login screen opened over Home closes it and returns to Home', (tester) async {
    await pumpApp(tester);
    final router = lastContainer!.read(appRouterProvider);
    router.go('/home');
    await tester.pumpAndSettle();
    router.push('/login');
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);

    await requestCodeFor(tester, '8190858375');
    // Six digits submit on their own.
    await tester.enterText(find.widgetWithText(TextFormField, 'Login code'), '123456');
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsNothing);
    expect(find.text('Shop by category'), findsOneWidget);
  });
}
