import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/core/auth/auth_session.dart';
import 'package:kv_silver_mobile/core/storage/secure_token_storage.dart';
import 'package:kv_silver_mobile/main.dart';
import '../../support/fake_secure_storage_client.dart';

void main() {
  testWidgets('redirects to /login when unauthenticated, then /home once a token is set', (tester) async {
    final storage = SecureTokenStorage(FakeSecureStorageClient());
    final container = ProviderContainer(
      overrides: [secureTokenStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const KvSilverMobileApp()),
    );
    await tester.pump();

    await container.read(authSessionProvider.notifier).restoreSession();
    await tester.pumpAndSettle();
    expect(find.text('Login'), findsOneWidget);

    await container.read(authSessionProvider.notifier).setToken('token-123');
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });
}
