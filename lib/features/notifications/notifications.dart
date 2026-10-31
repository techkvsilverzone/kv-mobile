import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_session.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    this.route,
    required this.read,
    this.createdAt,
  });

  final String id;

  /// 'order' | 'payment' | 'savings' | 'return' | 'general'.
  final String kind;
  final String title, body;

  /// Storefront path (e.g. `/order/12`); see [appRouteFor].
  final String? route;
  final bool read;
  final DateTime? createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: (j['_id'] ?? j['id'] ?? '').toString(),
        kind: (j['kind'] ?? 'general').toString(),
        title: (j['title'] ?? '').toString(),
        body: (j['body'] ?? '').toString(),
        route: (j['route'] as String?)?.isEmpty ?? true ? null : j['route'] as String,
        read: j['read'] == true,
        createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString()),
      );
}

class NotificationInbox {
  const NotificationInbox({this.notifications = const [], this.unreadCount = 0});
  final List<AppNotification> notifications;
  final int unreadCount;
}

/// Server routes are the storefront's paths; the app's order page lives at `/orders/:id`.
String appRouteFor(String route) =>
    route.startsWith('/order/') ? '/orders/${route.substring('/order/'.length)}' : route;

class NotificationRepository {
  NotificationRepository(this._api);
  final ApiClient _api;

  Future<NotificationInbox> fetch() async {
    final data = await _api.get('/users/me/notifications');
    final m = data is Map ? data : const {};
    return NotificationInbox(
      notifications: m['notifications'] is List
          ? (m['notifications'] as List)
              .whereType<Map>()
              .map((e) => AppNotification.fromJson(e.cast<String, dynamic>()))
              .toList()
          : const [],
      unreadCount: (m['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> markRead(String id) => _api.post('/users/me/notifications/$id/read');
  Future<void> markAllRead() => _api.post('/users/me/notifications/read-all');
  Future<void> registerPushToken(String token, String platform) =>
      _api.post('/users/me/push-tokens', data: {'token': token, 'platform': platform});
  Future<void> unregisterPushToken(String token) =>
      _api.delete('/users/me/push-tokens', data: {'token': token});
}

final notificationRepositoryProvider =
    Provider<NotificationRepository>((ref) => NotificationRepository(ref.watch(apiClientProvider)));

/// Empty while signed out.
final notificationInboxProvider = FutureProvider<NotificationInbox>((ref) async {
  if (!ref.watch(authSessionProvider).isAuthenticated) return const NotificationInbox();
  return ref.watch(notificationRepositoryProvider).fetch();
});

final unreadNotificationsProvider =
    Provider<int>((ref) => ref.watch(notificationInboxProvider).valueOrNull?.unreadCount ?? 0);
