import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'notifications.dart';

IconData _iconFor(String kind) => switch (kind) {
      'order' => Icons.local_shipping_outlined,
      'payment' => Icons.payments_outlined,
      'savings' => Icons.savings_outlined,
      'return' => Icons.replay,
      _ => Icons.notifications_none,
    };

/// "Just now", "5m ago", "3h ago", "Yesterday", else "12 Oct 2026".
String relativeTime(DateTime t, DateTime now) {
  final d = now.difference(t);
  if (d.inMinutes < 1) return 'Just now';
  if (d.inHours < 1) return '${d.inMinutes}m ago';
  if (d.inDays < 1) return '${d.inHours}h ago';
  if (d.inDays < 2) return 'Yesterday';
  return DateFormat('d MMM y').format(t);
}

/// `/notifications`: the signed-in customer's inbox.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, AppNotification n) async {
    if (!n.read) {
      try {
        await ref.read(notificationRepositoryProvider).markRead(n.id);
      } catch (_) {/* opening still works */}
      ref.invalidate(notificationInboxProvider);
    }
    if (n.route != null && context.mounted) context.push(appRouteFor(n.route!));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final inbox = ref.watch(notificationInboxProvider);
    final list = inbox.valueOrNull?.notifications ?? const <AppNotification>[];
    final unread = inbox.valueOrNull?.unreadCount ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () async {
                await ref.read(notificationRepositoryProvider).markAllRead();
                ref.invalidate(notificationInboxProvider);
              },
              child: const Text('Mark all as read'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(notificationInboxProvider),
        child: inbox.isLoading && list.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : inbox.hasError && list.isEmpty
                ? ListView(children: [
                    const SizedBox(height: 120),
                    Center(
                      child: TextButton(
                        onPressed: () => ref.invalidate(notificationInboxProvider),
                        child: const Text('Could not load notifications. Try again'),
                      ),
                    ),
                  ])
                : list.isEmpty
                    ? ListView(padding: const EdgeInsets.all(32), children: [
                        const SizedBox(height: 80),
                        Icon(Icons.notifications_none, size: 48, color: scheme.onSurfaceVariant),
                        const SizedBox(height: 16),
                        Text("You're all caught up",
                            textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text('Order, payment and savings updates will appear here.',
                            textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
                      ])
                    : ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final n = list[i];
                          return ListTile(
                            tileColor: n.read ? null : scheme.primary.withValues(alpha: 0.06),
                            leading: CircleAvatar(
                              backgroundColor: scheme.secondary,
                              child: Icon(_iconFor(n.kind), size: 20, color: scheme.primary),
                            ),
                            title: Text(n.title,
                                style: TextStyle(fontWeight: n.read ? FontWeight.w500 : FontWeight.w700)),
                            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(n.body),
                              if (n.createdAt != null)
                                Text(relativeTime(n.createdAt!.toLocal(), DateTime.now()),
                                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                            ]),
                            trailing: n.read
                                ? null
                                : Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle)),
                            onTap: () => _open(context, ref, n),
                          );
                        },
                      ),
      ),
    );
  }
}

/// App-bar bell with the unread count; shown to signed-in users.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadNotificationsProvider);
    return Badge(
      isLabelVisible: count > 0,
      label: Text(count > 99 ? '99+' : '$count'),
      child: IconButton(
        icon: const Icon(Icons.notifications_none),
        tooltip: 'Notifications',
        onPressed: () => context.push('/notifications'),
      ),
    );
  }
}
