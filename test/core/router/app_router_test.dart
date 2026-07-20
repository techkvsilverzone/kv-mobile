import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/core/api/api_exception.dart';
import 'package:kv_silver_mobile/core/auth/auth_session.dart';
import 'package:kv_silver_mobile/core/storage/secure_token_storage.dart';
import 'package:kv_silver_mobile/features/auth/data/auth_repository.dart';
import 'package:kv_silver_mobile/main.dart';
import '../../support/fake_auth_repository.dart';
import '../../support/fake_secure_storage_client.dart';

void main() {
  late SecureTokenStorage storage;
  late FakeAuthRepository repo;

  setUp(() {
    storage = SecureTokenStorage(FakeSecureStorageClient());
    repo = FakeAuthRepository();
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        secureTokenStorageProvider.overrideWithValue(storage),
        authRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> pumpApp(WidgetTester tester, ProviderContainer container) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const KvSilverMobileApp()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lands on login when there is no stored token', (tester) async {
    final container = makeContainer();
    await pumpApp(tester, container);

    expect(find.text('Welcome back'), findsOneWidget);
    expect(repo.getMeCalls, 0);
  });

  testWidgets('a valid stored token restores straight to home', (tester) async {
    await storage.saveToken('good-token');
    repo.user = buildUser(name: 'Asha');
    final container = makeContainer();

    await pumpApp(tester, container);

    expect(find.text('Welcome, Asha'), findsOneWidget);
    expect(repo.getMeCalls, 1);
  });

  testWidgets('signing in redirects to home off the auth-state change', (tester) async {
    final container = makeContainer();
    await pumpApp(tester, container);
    expect(find.text('Welcome back'), findsOneWidget);

    await container
        .read(authSessionProvider.notifier)
        .setSession(user: buildUser(name: 'Ravi'), token: 'token-123');
    await tester.pumpAndSettle();

    expect(find.text('Welcome, Ravi'), findsOneWidget);
  });

  testWidgets('clearing the session bounces back to login', (tester) async {
    await storage.saveToken('good-token');
    final container = makeContainer();
    await pumpApp(tester, container);

    await container.read(authSessionProvider.notifier).clearSession();
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('signup is reachable while signed out', (tester) async {
    final container = makeContainer();
    await pumpApp(tester, container);

    await tester.tap(find.widgetWithText(TextButton, 'Sign up'));
    await tester.pumpAndSettle();

    // Would have been bounced to /login if /signup were not public.
    expect(find.text('Create your account'), findsOneWidget);
  });

  testWidgets('an unreachable server holds on splash with a retry instead of logging out',
      (tester) async {
    await storage.saveToken('good-token');
    repo.getMeError = const NetworkException('Unable to reach the server.');
    final container = makeContainer();

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const KvSilverMobileApp()),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Unable to reach the server.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Welcome back'), findsNothing);

    // The token survives so the retry can succeed.
    expect(await storage.readToken(), 'good-token');

    repo.getMeError = null;
    repo.user = buildUser(name: 'Asha');
    await tester.tap(find.widgetWithText(FilledButton, 'Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome, Asha'), findsOneWidget);
  });
}
