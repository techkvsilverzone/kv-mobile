import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/secure_storage_client.dart';
import '../storage/secure_token_storage.dart';

class AuthSessionState {
  const AuthSessionState({required this.isAuthenticated, required this.isRestoring});

  final bool isAuthenticated;
  final bool isRestoring;

  static const initial = AuthSessionState(isAuthenticated: false, isRestoring: true);

  AuthSessionState copyWith({bool? isAuthenticated, bool? isRestoring}) => AuthSessionState(
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
        isRestoring: isRestoring ?? this.isRestoring,
      );
}

class AuthSessionController extends StateNotifier<AuthSessionState> {
  AuthSessionController(this._tokenStorage) : super(AuthSessionState.initial);

  final SecureTokenStorage _tokenStorage;

  Future<void> restoreSession() async {
    final token = await _tokenStorage.readToken();
    state = state.copyWith(
      isAuthenticated: token != null && token.isNotEmpty,
      isRestoring: false,
    );
  }

  Future<void> setToken(String token) async {
    await _tokenStorage.saveToken(token);
    state = state.copyWith(isAuthenticated: true, isRestoring: false);
  }

  Future<void> clearSession() async {
    await _tokenStorage.clearToken();
    state = state.copyWith(isAuthenticated: false, isRestoring: false);
  }
}

final secureTokenStorageProvider = Provider<SecureTokenStorage>((ref) {
  return SecureTokenStorage(FlutterSecureStorageClient());
});

final authSessionProvider = StateNotifierProvider<AuthSessionController, AuthSessionState>((ref) {
  return AuthSessionController(ref.watch(secureTokenStorageProvider));
});
