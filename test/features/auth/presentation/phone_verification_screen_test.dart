import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/core/api/api_exception.dart';
import 'package:kv_silver_mobile/core/auth/auth_session.dart';
import 'package:kv_silver_mobile/core/router/app_router.dart';
import 'package:kv_silver_mobile/core/storage/secure_token_storage.dart';
import 'package:kv_silver_mobile/features/auth/data/auth_repository.dart';
import 'package:kv_silver_mobile/main.dart';
import 'package:kv_silver_mobile/features/store_config/marquee_bar.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_secure_storage_client.dart';

void main() {
  late FakeAuthRepository repo;
  late SecureTokenStorage storage;

  setUp(() {
    repo = FakeAuthRepository();
    storage = SecureTokenStorage(FakeSecureStorageClient());
  });

  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        marqueeAnimatedProvider.overrideWithValue(false),
        secureTokenStorageProvider.overrideWithValue(storage),
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
    // Guests land on home; these flows start from the login screen.
    container.read(appRouterProvider).go('/login');
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> signUp(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(TextButton, 'Sign up'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Full Name'), 'Vino');
    await tester.enterText(find.widgetWithText(TextFormField, 'Email Address'), 'vino@example.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Mobile Number'), '8190858375');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret1');
    await tester.enterText(find.widgetWithText(TextFormField, 'Confirm Password'), 'secret1');
    await tapVisible(tester, find.byType(CheckboxListTile));
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Create Account'));
  }

  testWidgets('signup lands on verification without re-sending the code, and a code verifies', (tester) async {
    await pumpApp(tester);
    await signUp(tester);

    expect(find.text('Verify your mobile'), findsOneWidget);
    expect(find.text('Enter the 6-digit code sent on WhatsApp to +91 8190858375'), findsOneWidget);
    expect(repo.phoneCodeRequests, 0);

    await tester.enterText(find.widgetWithText(TextFormField, 'Verification code'), '482913');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Verify'));

    expect(repo.lastPhoneCode, '482913');
    expect(find.text('KV SILVER ZONE EXCLUSIVE'), findsOneWidget);
  });

  testWidgets('verification can be skipped', (tester) async {
    await pumpApp(tester);
    await signUp(tester);

    await tapVisible(tester, find.widgetWithText(TextButton, 'Skip for now'));

    expect(find.text('KV SILVER ZONE EXCLUSIVE'), findsOneWidget);
  });

  testWidgets('Profile offers verification for an unverified number and shows a wrong-code error',
      (tester) async {
    await storage.saveToken('good-token');
    repo.user = buildUser(name: 'Asha', phone: '9876543210');
    repo.verifyPhoneError = const ValidationException('Incorrect code.', {});
    final container = await pumpApp(tester);

    container.read(appRouterProvider).push('/profile');
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Verify mobile number'));

    expect(repo.phoneCodeRequests, 1);
    await tester.enterText(find.widgetWithText(TextFormField, 'Verification code'), '000000');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Verify'));

    expect(find.text('Incorrect code.'), findsOneWidget);
    expect(container.read(currentUserProvider)!.phoneVerified, isFalse);
  });

  testWidgets('Profile hides the verify option once the number is verified', (tester) async {
    await storage.saveToken('good-token');
    repo.user = buildUser(name: 'Asha', phone: '9876543210', phoneVerified: true);
    final container = await pumpApp(tester);

    container.read(appRouterProvider).push('/profile');
    await tester.pumpAndSettle();

    expect(find.text('Verify mobile number'), findsNothing);
  });
}
