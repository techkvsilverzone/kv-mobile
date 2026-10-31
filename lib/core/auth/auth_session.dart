import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/data/models/user.dart';
import '../api/api_exception.dart';
import '../storage/secure_storage_client.dart';
import '../storage/secure_token_storage.dart';

class AuthSessionState {
  const AuthSessionState({
    required this.user,
    required this.isRestoring,
    this.restoreError,
    this.justSignedUp = false,
  });

  /// The signed-in user, or null when signed out. A stored token alone is not
  /// enough to be authenticated — it must have been validated against
  /// `GET /users/me`, because the server has no refresh endpoint and a 30-day
  /// JWT can be revoked or belong to a since-deleted account.
  final User? user;

  /// True until the cold-start restore settles. Also stays true when restore
  /// fails for a *recoverable* reason (see [restoreError]) so the router keeps
  /// the user on the splash screen instead of bouncing them to login while a
  /// perfectly good token sits in storage.
  final bool isRestoring;

  /// Set when restore failed because the server was unreachable — not because
  /// the token was rejected. The splash screen surfaces this with a retry.
  final String? restoreError;

  /// The session began with signup (not login/restore). Signup has already sent a WhatsApp
  /// verification code, so the router offers the verification screen before Home.
  final bool justSignedUp;

  bool get isAuthenticated => user != null;

  static const initial = AuthSessionState(user: null, isRestoring: true);

  AuthSessionState copyWith({
    User? user,
    bool? isRestoring,
    String? restoreError,
    bool clearUser = false,
    bool clearError = false,
  }) =>
      AuthSessionState(
        user: clearUser ? null : (user ?? this.user),
        isRestoring: isRestoring ?? this.isRestoring,
        restoreError: clearError ? null : (restoreError ?? this.restoreError),
        justSignedUp: justSignedUp,
      );
}

class AuthSessionController extends StateNotifier<AuthSessionState> {
  AuthSessionController(this._ref, this._tokenStorage) : super(AuthSessionState.initial);

  /// Read lazily rather than injected: [AuthRepository] is built on top of the
  /// Dio client, whose 401 interceptor calls back into this controller.
  /// Resolving it at construction time would close that loop into a circular
  /// provider dependency.
  final Ref _ref;
  final SecureTokenStorage _tokenStorage;

  AuthRepository get _repo => _ref.read(authRepositoryProvider);

  /// Cold start: a stored token is only trusted after `GET /users/me` confirms
  /// it. Mirrors the web's `initAuth`, but distinguishes "token rejected" from
  /// "server unreachable" — the web logs you out for both, which silently drops
  /// a valid session whenever the network hiccups.
  Future<void> restoreSession() async {
    state = state.copyWith(isRestoring: true, clearError: true);

    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      state = const AuthSessionState(user: null, isRestoring: false);
      return;
    }

    try {
      final user = await _repo.getMe();
      state = AuthSessionState(user: user, isRestoring: false);
    } on AuthException {
      await _tokenStorage.clearToken();
      state = const AuthSessionState(user: null, isRestoring: false);
    } on ApiException catch (e) {
      // Keep the token — the session is probably still valid; we just could not
      // confirm it. Staying "restoring" holds the router on /splash.
      state = state.copyWith(clearUser: true, isRestoring: true, restoreError: e.message);
    }
  }

  /// Called after a successful login/signup/OTP verify, where the user object
  /// arrives alongside the token so no extra round trip is needed.
  Future<void> setSession({required User user, required String token, bool justSignedUp = false}) async {
    await _tokenStorage.saveToken(token);
    state = AuthSessionState(user: user, isRestoring: false, justSignedUp: justSignedUp);
  }

  /// Replaces the cached user after a profile edit without touching the token.
  void updateUser(User user) {
    if (state.user == null) return;
    state = state.copyWith(user: user);
  }

  /// Local-only teardown. Invoked by the Dio 401 interceptor, so it must not
  /// itself issue a request or a rejected call would recurse.
  Future<void> clearSession() async {
    await _tokenStorage.clearToken();
    state = const AuthSessionState(user: null, isRestoring: false);
  }

  final _signOutHooks = <Future<void> Function()>[];

  /// Work that needs the session still valid, run just before a user sign-out
  /// (e.g. unregistering this device from push).
  void addSignOutHook(Future<void> Function() hook) => _signOutHooks.add(hook);

  /// User-initiated sign out: tell the server, then clear locally regardless.
  Future<void> signOut() async {
    for (final hook in _signOutHooks) {
      try {
        await hook();
      } catch (_) {/* never block sign-out */}
    }
    await _repo.logout();
    await clearSession();
  }
}

final secureTokenStorageProvider = Provider<SecureTokenStorage>((ref) {
  return SecureTokenStorage(FlutterSecureStorageClient());
});

final authSessionProvider = StateNotifierProvider<AuthSessionController, AuthSessionState>((ref) {
  return AuthSessionController(ref, ref.watch(secureTokenStorageProvider));
});

/// Convenience for widgets that only care about who is signed in.
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authSessionProvider).user;
});
