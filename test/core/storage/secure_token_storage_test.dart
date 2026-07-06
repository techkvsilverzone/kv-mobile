import 'package:flutter_test/flutter_test.dart';
import 'package:kv_silver_mobile/core/storage/secure_token_storage.dart';
import '../../support/fake_secure_storage_client.dart';

void main() {
  test('readToken returns null before any token is saved', () async {
    final storage = SecureTokenStorage(FakeSecureStorageClient());
    expect(await storage.readToken(), isNull);
  });

  test('saveToken then readToken round-trips the value', () async {
    final storage = SecureTokenStorage(FakeSecureStorageClient());
    await storage.saveToken('abc.def.ghi');
    expect(await storage.readToken(), 'abc.def.ghi');
  });

  test('clearToken removes the stored value', () async {
    final storage = SecureTokenStorage(FakeSecureStorageClient());
    await storage.saveToken('abc.def.ghi');
    await storage.clearToken();
    expect(await storage.readToken(), isNull);
  });
}
