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
        splashAnimatedProvider.overrideWithValue(false),
        secureTokenStorageProvider.overrideWithValue(storage),
        authRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> pumpApp(WidgetTester tester, ProviderContainer container) async {
    // Room for the marquee strip above every screen.
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const KvSilverMobileApp()),
    );
    await tester.pumpAndSettle();
  }

  Future<void> go(WidgetTester tester, ProviderContainer container, String location) async {
    container.read(appRouterProvider).go(location);
    await tester.pumpAndSettle();
  }

  testWidgets('a guest lands on home without being asked to sign in', (tester) async {
    final container = makeContainer();
    await pumpApp(tester, container);

    expect(find.text('Shop by category'), findsOneWidget);
    expect(find.text('Welcome back'), findsNothing);
    expect(repo.getMeCalls, 0);
  });

  testWidgets('a valid stored token restores straight to home', (tester) async {
    await storage.saveToken('good-token');
    repo.user = buildUser(name: 'Asha');
    final container = makeContainer();

    await pumpApp(tester, container);

    expect(find.text('Shop by category'), findsOneWidget);
    expect(repo.getMeCalls, 1);
  });

  testWidgets('a protected page sends a guest to login, then back there after signing in', (tester) async {
    final container = makeContainer();
    await pumpApp(tester, container);
    await go(tester, container, '/orders');
    expect(find.text('Welcome back'), findsOneWidget);

    await container
        .read(authSessionProvider.notifier)
        .setSession(user: buildUser(name: 'Ravi'), token: 'token-123');
    await tester.pumpAndSettle();

    expect(find.text('My orders'), findsOneWidget);
  });

  testWidgets('signing in from the login screen redirects to home', (tester) async {
    final container = makeContainer();
    await pumpApp(tester, container);
    await go(tester, container, '/login');

    await container
        .read(authSessionProvider.notifier)
        .setSession(user: buildUser(name: 'Ravi'), token: 'token-123');
    await tester.pumpAndSettle();

    expect(find.text('Shop by category'), findsOneWidget);
  });

  testWidgets('clearing the session on a protected page bounces back to login', (tester) async {
    await storage.saveToken('good-token');
    final container = makeContainer();
    await pumpApp(tester, container);
    await go(tester, container, '/orders');

    await container.read(authSessionProvider.notifier).clearSession();
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('signup is reachable while signed out', (tester) async {
    final container = makeContainer();
    await pumpApp(tester, container);
    await go(tester, container, '/login');

    await tester.tap(find.widgetWithText(TextButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Join KV Silver Zone for exclusive offers.'), findsOneWidget);
  });

  testWidgets('an unreachable server holds on splash with a retry instead of logging out',
      (tester) async {
    await storage.saveToken('good-token');
    repo.getMeError = const NetworkException('Unable to reach the server.');
    final container = makeContainer();

    // Room for the marquee strip above every screen.
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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

    expect(find.text('Shop by category'), findsOneWidget);
  });
}
