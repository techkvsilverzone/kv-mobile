import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/core/auth/auth_session.dart';
import 'package:kv_silver_mobile/core/storage/secure_token_storage.dart';
import '../../support/fake_secure_storage_client.dart';

void main() {
  ProviderContainer makeContainer() {
    final storage = SecureTokenStorage(FakeSecureStorageClient());
    return ProviderContainer(
      overrides: [secureTokenStorageProvider.overrideWithValue(storage)],
    );
  }

  test('initial state is restoring and unauthenticated', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    expect(container.read(authSessionProvider).isRestoring, isTrue);
    expect(container.read(authSessionProvider).isAuthenticated, isFalse);
  });

  test('restoreSession with no stored token settles to unauthenticated', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(authSessionProvider.notifier).restoreSession();
    final state = container.read(authSessionProvider);
    expect(state.isRestoring, isFalse);
    expect(state.isAuthenticated, isFalse);
  });

  test('setToken marks the session authenticated', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(authSessionProvider.notifier).setToken('token-123');
    final state = container.read(authSessionProvider);
    expect(state.isAuthenticated, isTrue);
    expect(state.isRestoring, isFalse);
  });

  test('clearSession marks the session unauthenticated', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(authSessionProvider.notifier).setToken('token-123');
    await container.read(authSessionProvider.notifier).clearSession();
    expect(container.read(authSessionProvider).isAuthenticated, isFalse);
  });

  test('restoreSession finds a previously saved token', () async {
    final storage = SecureTokenStorage(FakeSecureStorageClient());
    await storage.saveToken('existing-token');
    final container = ProviderContainer(
      overrides: [secureTokenStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    await container.read(authSessionProvider.notifier).restoreSession();
    expect(container.read(authSessionProvider).isAuthenticated, isTrue);
  });
}
