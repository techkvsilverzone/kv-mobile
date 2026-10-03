import 'package:kv_silver_mobile/core/api/api_exception.dart';
import 'package:kv_silver_mobile/features/auth/data/auth_repository.dart';
import 'package:kv_silver_mobile/features/auth/data/models/user.dart';

User buildUser({String id = 'user-1', String name = 'Asha', String email = 'asha@example.com'}) {
  return User(id: id, name: name, email: email, role: 'customer');
}

/// Test double for [AuthRepository]. `implements` rather than `extends` so no
/// real [ApiClient]/Dio has to be constructed — the private `_api` field is not
/// part of the interface outside its own library.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.user, this.getMeError});

  User? user;

  /// When set, [getMe] throws this instead of returning [user].
  ApiException? getMeError;

  /// When set, [requestOtp] throws this (e.g. the API's 404 for an unregistered number).
  ApiException? requestOtpError;

  String? lastOtpPhone;
  String? lastSignupPhone;

  int getMeCalls = 0;
  int logoutCalls = 0;
  Map<String, dynamic>? lastUpdate;

  @override
  Future<User> getMe() async {
    getMeCalls++;
    final error = getMeError;
    if (error != null) throw error;
    return user ?? buildUser();
  }

  @override
  Future<AuthResult> login({required String email, required String password}) async {
    return AuthResult(user: user ?? buildUser(email: email), token: 'token-login');
  }

  @override
  Future<AuthResult> signup({
    required String name,
    required String email,
    required String password,
    required String phone,
    bool stallEvent = false,
  }) async {
    lastSignupPhone = phone;
    return AuthResult(
      user: user ?? buildUser(name: name, email: email),
      token: 'token-signup',
      promoCoupon: stallEvent ? 'STALL10' : null,
    );
  }

  @override
  Future<String> requestOtp(String phone) async {
    lastOtpPhone = phone;
    final error = requestOtpError;
    if (error != null) throw error;
    return 'Code sent';
  }

  @override
  Future<AuthResult> verifyOtp({required String phone, required String code}) async {
    lastOtpPhone = phone;
    return AuthResult(user: user ?? buildUser(), token: 'token-otp');
  }

  @override
  Future<void> forgotPassword(String email) async {}

  @override
  Future<User> updateMe(Map<String, dynamic> changes) async {
    lastUpdate = changes;
    final updated = buildUser(name: (changes['name'] as String?) ?? 'Asha');
    user = updated;
    return updated;
  }

  @override
  Future<void> changePassword({required String userId, required String password}) async {}

  @override
  Future<void> logout() async {
    logoutCalls++;
  }
}
