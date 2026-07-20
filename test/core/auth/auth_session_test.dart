import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/core/api/api_exception.dart';
import 'package:kv_silver_mobile/core/auth/auth_session.dart';
import 'package:kv_silver_mobile/core/storage/secure_token_storage.dart';
import 'package:kv_silver_mobile/features/auth/data/auth_repository.dart';
import '../../support/fake_auth_repository.dart';
import '../../support/fake_secure_storage_client.dart';

void main() {
  late SecureTokenStorage storage;
  late FakeAuthRepository repo;

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

  setUp(() {
    storage = SecureTokenStorage(FakeSecureStorageClient());
    repo = FakeAuthRepository();
  });

  test('initial state is restoring and unauthenticated', () {
    final container = makeContainer();
    expect(container.read(authSessionProvider).isRestoring, isTrue);
    expect(container.read(authSessionProvider).isAuthenticated, isFalse);
  });

  test('restoreSession with no stored token settles to unauthenticated without calling the API',
      () async {
    final container = makeContainer();
    await container.read(authSessionProvider.notifier).restoreSession();

    final state = container.read(authSessionProvider);
    expect(state.isRestoring, isFalse);
    expect(state.isAuthenticated, isFalse);
    expect(repo.getMeCalls, 0);
  });

  test('restoreSession validates a stored token against /users/me', () async {
    await storage.saveToken('existing-token');
    repo.user = buildUser(name: 'Asha');
    final container = makeContainer();

    await container.read(authSessionProvider.notifier).restoreSession();

    final state = container.read(authSessionProvider);
    expect(repo.getMeCalls, 1);
    expect(state.isAuthenticated, isTrue);
    expect(state.user?.name, 'Asha');
    expect(state.isRestoring, isFalse);
  });

  test('a rejected token is discarded so the next launch does not retry it', () async {
    await storage.saveToken('stale-token');
    repo.getMeError = const AuthException('Invalid token. Please log in again!');
    final container = makeContainer();

    await container.read(authSessionProvider.notifier).restoreSession();

    expect(container.read(authSessionProvider).isAuthenticated, isFalse);
    expect(container.read(authSessionProvider).isRestoring, isFalse);
    expect(await storage.readToken(), isNull);
  });

  test('an unreachable server keeps the token and stays restoring with an error', () async {
    await storage.saveToken('good-token');
    repo.getMeError = const NetworkException('Unable to reach the server.');
    final container = makeContainer();

    await container.read(authSessionProvider.notifier).restoreSession();

    final state = container.read(authSessionProvider);
    expect(state.isAuthenticated, isFalse);
    // Still "restoring" so the router holds on /splash and offers a retry,
    // rather than logging the user out over a flaky connection.
    expect(state.isRestoring, isTrue);
    expect(state.restoreError, 'Unable to reach the server.');
    expect(await storage.readToken(), 'good-token');
  });

  test('retrying after a network failure recovers the session', () async {
    await storage.saveToken('good-token');
    repo.getMeError = const NetworkException('Unable to reach the server.');
    final container = makeContainer();
    await container.read(authSessionProvider.notifier).restoreSession();

    repo.getMeError = null;
    await container.read(authSessionProvider.notifier).restoreSession();

    final state = container.read(authSessionProvider);
    expect(state.isAuthenticated, isTrue);
    expect(state.isRestoring, isFalse);
    expect(state.restoreError, isNull);
  });

  test('setSession stores the token and marks the session authenticated', () async {
    final container = makeContainer();
    await container
        .read(authSessionProvider.notifier)
        .setSession(user: buildUser(name: 'Ravi'), token: 'token-123');

    final state = container.read(authSessionProvider);
    expect(state.isAuthenticated, isTrue);
    expect(state.user?.name, 'Ravi');
    expect(await storage.readToken(), 'token-123');
  });

  test('clearSession drops both the user and the stored token', () async {
    final container = makeContainer();
    await container
        .read(authSessionProvider.notifier)
        .setSession(user: buildUser(), token: 'token-123');

    await container.read(authSessionProvider.notifier).clearSession();

    expect(container.read(authSessionProvider).isAuthenticated, isFalse);
    expect(await storage.readToken(), isNull);
  });

  test('signOut notifies the server then clears locally', () async {
    final container = makeContainer();
    await container
        .read(authSessionProvider.notifier)
        .setSession(user: buildUser(), token: 'token-123');

    await container.read(authSessionProvider.notifier).signOut();

    expect(repo.logoutCalls, 1);
    expect(container.read(authSessionProvider).isAuthenticated, isFalse);
    expect(await storage.readToken(), isNull);
  });

  test('updateUser replaces the cached user without touching the token', () async {
    final container = makeContainer();
    await container
        .read(authSessionProvider.notifier)
        .setSession(user: buildUser(name: 'Asha'), token: 'token-123');

    container.read(authSessionProvider.notifier).updateUser(buildUser(name: 'Asha Kumar'));

    expect(container.read(authSessionProvider).user?.name, 'Asha Kumar');
    expect(await storage.readToken(), 'token-123');
  });

  test('updateUser is a no-op when signed out', () {
    final container = makeContainer();
    container.read(authSessionProvider.notifier).updateUser(buildUser());
    expect(container.read(authSessionProvider).isAuthenticated, isFalse);
  });
}
