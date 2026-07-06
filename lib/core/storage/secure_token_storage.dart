import 'secure_storage_client.dart';

class SecureTokenStorage {
  SecureTokenStorage(this._client);

  final SecureStorageClient _client;
  static const _tokenKey = 'kv_silver_mobile.auth_token';

  Future<void> saveToken(String token) => _client.write(_tokenKey, token);
  Future<String?> readToken() => _client.read(_tokenKey);
  Future<void> clearToken() => _client.delete(_tokenKey);
}
