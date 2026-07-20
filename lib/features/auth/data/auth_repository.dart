import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import 'models/user.dart';

/// Wraps `kv-api`'s auth surface. Every method here throws an [ApiException]
/// subtype on failure (mapped by [ApiClient]) — callers never see a
/// `DioException`.
class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  Future<AuthResult> login({required String email, required String password}) async {
    final data = await _api.post('/auth/login', data: {'email': email, 'password': password});
    return AuthResult.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<AuthResult> signup({
    required String name,
    required String email,
    required String password,
    String? phone,
    bool stallEvent = false,
  }) async {
    final data = await _api.post('/auth/signup', data: {
      'name': name,
      'email': email,
      'password': password,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (stallEvent) 'stallEvent': true,
    });
    return AuthResult.fromJson((data as Map).cast<String, dynamic>());
  }

  /// Sends a 6-digit login code by email. Returns the server's confirmation
  /// message.
  Future<String> requestOtp(String email) async {
    final data = await _api.post('/auth/otp/request', data: {'email': email});
    if (data is Map && data['message'] is String) return data['message'] as String;
    return 'Code sent';
  }

  Future<AuthResult> verifyOtp({required String email, required String code}) async {
    final data = await _api.post('/auth/otp/verify', data: {'email': email, 'code': code});
    return AuthResult.fromJson((data as Map).cast<String, dynamic>());
  }

  /// NOTE: `/auth/forgot-password` is currently a no-op stub server-side — it
  /// ignores the body and always 200s without sending mail. Kept so the flow
  /// exists and starts working the moment the endpoint is implemented; the UI
  /// must not promise more than this delivers.
  Future<void> forgotPassword(String email) async {
    await _api.post('/auth/forgot-password', data: {'email': email});
  }

  Future<User> getMe() async {
    final data = await _api.get('/users/me');
    return User.fromJson((data as Map).cast<String, dynamic>());
  }

  /// `PUT /users/me` returns the raw Mongoose document — it leaks
  /// `passwordHash` and drops the computed `role` field. We discard that body
  /// and re-read `GET /users/me` so callers always get a clean, fully-populated
  /// user.
  Future<User> updateMe(Map<String, dynamic> changes) async {
    await _api.put('/users/me', data: changes);
    return getMe();
  }

  Future<void> changePassword({required String userId, required String password}) async {
    await _api.put('/users/$userId/password', data: {'password': password});
  }

  /// Fire-and-forget: the local session is cleared regardless of the outcome,
  /// so a failure here must not block logout.
  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } catch (_) {
      // Intentionally ignored — clearing the local token is what matters.
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});
