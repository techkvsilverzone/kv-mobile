import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/validation/validators.dart';
import '../data/auth_repository.dart';

/// Outcome of a submitted auth form. Screens render [error] inline rather than
/// only toasting it — the web app swallows server messages and shows a generic
/// "Invalid email or password" even for a network outage, which is worth
/// improving on rather than porting.
class AuthSubmission {
  const AuthSubmission._({required this.ok, this.error, this.promoCoupon});

  const AuthSubmission.success({String? promoCoupon})
      : this._(ok: true, promoCoupon: promoCoupon);
  const AuthSubmission.failure(String message) : this._(ok: false, error: message);

  final bool ok;
  final String? error;
  final String? promoCoupon;
}

/// Drives the auth forms. Holds only the in-flight flag; the resulting session
/// lives in [authSessionProvider], which is what the router watches.
class AuthController extends StateNotifier<bool> {
  AuthController(this._ref) : super(false);

  final Ref _ref;

  AuthRepository get _repo => _ref.read(authRepositoryProvider);
  AuthSessionController get _session => _ref.read(authSessionProvider.notifier);

  Future<AuthSubmission> _run(Future<AuthSubmission> Function() action) async {
    if (state) return const AuthSubmission.failure('Please wait…');
    state = true;
    try {
      return await action();
    } on ApiException catch (e) {
      return AuthSubmission.failure(e.message);
    } catch (_) {
      return const AuthSubmission.failure('Something went wrong. Please try again.');
    } finally {
      state = false;
    }
  }

  Future<AuthSubmission> login({required String email, required String password}) {
    return _run(() async {
      final result = await _repo.login(email: email.trim(), password: password);
      await _session.setSession(user: result.user, token: result.token);
      return const AuthSubmission.success();
    });
  }

  Future<AuthSubmission> signup({
    required String name,
    required String email,
    required String password,
    required String phone,
    bool stallEvent = false,
  }) {
    return _run(() async {
      final result = await _repo.signup(
        name: name.trim(),
        email: email.trim(),
        password: password,
        phone: normalizePhone(phone),
        stallEvent: stallEvent,
      );
      await _session.setSession(user: result.user, token: result.token, justSignedUp: true);
      return AuthSubmission.success(promoCoupon: result.promoCoupon);
    });
  }

  Future<AuthSubmission> requestOtp(String phone) {
    return _run(() async {
      await _repo.requestOtp(normalizePhone(phone));
      return const AuthSubmission.success();
    });
  }

  Future<AuthSubmission> verifyOtp({required String phone, required String code}) {
    return _run(() async {
      final result = await _repo.verifyOtp(phone: normalizePhone(phone), code: code.trim());
      await _session.setSession(user: result.user, token: result.token);
      return const AuthSubmission.success();
    });
  }

  Future<AuthSubmission> requestPhoneVerification() {
    return _run(() async {
      await _repo.requestPhoneVerification();
      return const AuthSubmission.success();
    });
  }

  Future<AuthSubmission> verifyPhone(String code) {
    return _run(() async {
      final user = await _repo.verifyPhone(code.trim());
      _session.updateUser(user);
      return const AuthSubmission.success();
    });
  }

  Future<AuthSubmission> forgotPassword(String email) {
    return _run(() async {
      await _repo.forgotPassword(email.trim());
      return const AuthSubmission.success();
    });
  }

  Future<AuthSubmission> updateProfile(Map<String, dynamic> changes) {
    return _run(() async {
      final user = await _repo.updateMe(changes);
      _session.updateUser(user);
      return const AuthSubmission.success();
    });
  }

  Future<AuthSubmission> changePassword(String password) {
    return _run(() async {
      final userId = _ref.read(authSessionProvider).user?.id;
      if (userId == null || userId.isEmpty) {
        return const AuthSubmission.failure('You are not signed in.');
      }
      await _repo.changePassword(userId: userId, password: password);
      return const AuthSubmission.success();
    });
  }
}

/// `true` while a submission is in flight — screens disable their submit button
/// on this rather than tracking it locally.
final authControllerProvider = StateNotifierProvider<AuthController, bool>((ref) {
  return AuthController(ref);
});
