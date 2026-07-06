import 'package:kv_silver_mobile/core/storage/secure_storage_client.dart';

class FakeSecureStorageClient implements SecureStorageClient {
  final Map<String, String> _values = {};

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}
