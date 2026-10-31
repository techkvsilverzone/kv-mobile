import 'dart:async';
import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_session.dart';
import 'notifications.dart';

/// Lets push show a toast without a BuildContext (wired into MaterialApp).
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// FCM push. Disabled (silently) when the build has no Firebase config
/// (android/app/google-services.json); the in-app inbox works either way.
class PushService {
  PushService(this._ref);

  final Ref _ref;
  bool _enabled = false;
  String? _token;
  GoRouter? _router;

  bool get enabled => _enabled;

  Future<void> start(GoRouter router) async {
    _router = router;
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('[push] Firebase not configured, push disabled: $e');
      return;
    }
    _enabled = true;
    final messaging = FirebaseMessaging.instance;

    _ref.listen<AuthSessionState>(authSessionProvider, (prev, next) {
      if (next.isAuthenticated && !(prev?.isAuthenticated ?? false)) unawaited(_register());
    });
    _ref.read(authSessionProvider.notifier).addSignOutHook(unregister);
    if (_ref.read(authSessionProvider).isAuthenticated) unawaited(_register());

    // shortcut: getToken/onTokenRefresh are deprecated in firebase_messaging 17 in favour of
    // register()/onRegistered, which yield an installation id rather than the registration token
    // the API sends to (FCM v1 `message.token`). Switch both sides together when upgrading.
    // ignore: deprecated_member_use
    messaging.onTokenRefresh.listen((t) {
      _token = t;
      if (_ref.read(authSessionProvider).isAuthenticated) unawaited(_send(t));
    });
    FirebaseMessaging.onMessage.listen((m) {
      _ref.invalidate(notificationInboxProvider);
      final n = m.notification;
      if (n == null) return;
      scaffoldMessengerKey.currentState
        ?..removeCurrentSnackBar()
        ..showSnackBar(SnackBar(
          persist: false,
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(n.title ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
            if ((n.body ?? '').isNotEmpty) Text(n.body!),
          ]),
          action: (m.data['route'] ?? '').toString().isEmpty
              ? null
              : SnackBarAction(label: 'View', onPressed: () => _open(m)),
        ));
    });
    FirebaseMessaging.onMessageOpenedApp.listen(_open);
    final initial = await messaging.getInitialMessage();
    if (initial != null) _open(initial);
  }

  void _open(RemoteMessage m) {
    _ref.invalidate(notificationInboxProvider);
    final route = (m.data['route'] ?? '').toString();
    _router?.push(route.isEmpty ? '/notifications' : appRouteFor(route));
  }

  Future<void> _register() async {
    try {
      // Asked once signed in, when order and savings updates are relevant —
      // not over the splash on first launch.
      await FirebaseMessaging.instance.requestPermission();
      // ignore: deprecated_member_use
      _token ??= await FirebaseMessaging.instance.getToken();
      if (_token != null) await _send(_token!);
    } catch (e) {
      debugPrint('[push] could not register this device: $e');
    }
  }

  Future<void> _send(String token) => _ref
      .read(notificationRepositoryProvider)
      .registerPushToken(token, Platform.isIOS ? 'ios' : 'android')
      .catchError((Object e) => debugPrint('[push] token upload failed: $e'));

  /// Called before sign-out so this phone stops getting the account's notifications.
  Future<void> unregister() async {
    final t = _token;
    if (!_enabled || t == null) return;
    try {
      await _ref.read(notificationRepositoryProvider).unregisterPushToken(t);
    } catch (_) {/* best-effort: the server also prunes dead tokens */}
  }
}

final pushServiceProvider = Provider<PushService>((ref) => PushService(ref));
