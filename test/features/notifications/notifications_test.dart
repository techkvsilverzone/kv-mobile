import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:kv_silver_mobile/core/api/api_client.dart';
import 'package:kv_silver_mobile/features/notifications/notifications.dart';
import 'package:kv_silver_mobile/features/notifications/notifications_screen.dart';

class _FakeRepo extends NotificationRepository {
  _FakeRepo(this.inbox) : super(ApiClient(Dio()));
  NotificationInbox inbox;
  final read = <String>[];
  @override
  Future<NotificationInbox> fetch() async => inbox;
  @override
  Future<void> markRead(String id) async => read.add(id);
}

void main() {
  test('maps the storefront order path to the app order screen', () {
    expect(appRouteFor('/order/42'), '/orders/42');
    expect(appRouteFor('/savings-scheme/passbook/SLV-1'), '/savings-scheme/passbook/SLV-1');
  });

  test('relative times', () {
    final now = DateTime(2026, 10, 31, 12);
    expect(relativeTime(now.subtract(const Duration(seconds: 20)), now), 'Just now');
    expect(relativeTime(now.subtract(const Duration(minutes: 5)), now), '5m ago');
    expect(relativeTime(now.subtract(const Duration(hours: 3)), now), '3h ago');
    expect(relativeTime(now.subtract(const Duration(hours: 30)), now), 'Yesterday');
    expect(relativeTime(DateTime(2026, 10, 12), now), '12 Oct 2026');
  });

  test('parses the inbox and treats an empty route as none', () {
    final n = AppNotification.fromJson(
        {'_id': '5', 'kind': 'order', 'title': 'Order shipped', 'body': 'On its way', 'route': '', 'read': false});
    expect(n.route, isNull);
    expect(n.read, isFalse);
  });

  testWidgets('tapping an unread notification marks it read and opens its page', (tester) async {
    final repo = _FakeRepo(NotificationInbox(unreadCount: 1, notifications: [
      AppNotification.fromJson({
        '_id': '9', 'kind': 'order', 'title': 'Order shipped', 'body': 'Your order #000042 is on its way.',
        'route': '/order/42', 'read': false, 'createdAt': DateTime.now().toIso8601String(),
      }),
    ]));
    final router = GoRouter(initialLocation: '/notifications', routes: [
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
      GoRoute(path: '/orders/:id', builder: (_, s) => Scaffold(body: Text('ORDER ${s.pathParameters['id']}'))),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        notificationRepositoryProvider.overrideWithValue(repo),
        notificationInboxProvider.overrideWith((ref) => ref.watch(notificationRepositoryProvider).fetch()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Mark all as read'), findsOneWidget);
    await tester.tap(find.text('Order shipped'));
    await tester.pumpAndSettle();
    expect(repo.read, ['9']);
    expect(find.text('ORDER 42'), findsOneWidget);
  });
}
