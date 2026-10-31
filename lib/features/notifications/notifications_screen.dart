import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/ui/kv_ui.dart';
import 'notifications.dart';

/// Icon and its tint per notification kind.
(IconData, Color, Color) _styleFor(String kind) => switch (kind) {
      'order' => (Icons.local_shipping_outlined, Kv.blueSoft, Kv.blue),
      'payment' => (Icons.payments_outlined, Kv.successSoft, Kv.success),
      'savings' => (Icons.savings_outlined, Kv.goldSoft, Kv.gold),
      'return' => (Icons.assignment_return_outlined, Kv.warningSoft, Kv.warning),
      _ => (Icons.notifications_none_rounded, const Color(0xFFEFF1F4), Kv.muted),
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

/// `/notifications`: the signed-in customer's inbox, grouped Today / Earlier.
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

  Future<void> _markAll(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(notificationRepositoryProvider).markAllRead();
    } catch (_) {
      if (context.mounted) showKvToast(context, "Couldn't mark as read", message: 'Please try again.', error: true);
    }
    ref.invalidate(notificationInboxProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(notificationInboxProvider);
    final list = inbox.valueOrNull?.notifications ?? const <AppNotification>[];
    final unread = inbox.valueOrNull?.unreadCount ?? 0;
    final now = DateTime.now();
    bool isToday(AppNotification n) {
      final t = n.createdAt?.toLocal();
      return t != null && t.year == now.year && t.month == now.month && t.day == now.day;
    }

    final today = list.where(isToday).toList();
    final earlier = list.where((n) => !isToday(n)).toList();

    Widget group(String title, List<AppNotification> items) => Padding(
          padding: const EdgeInsets.only(bottom: Kv.gap),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(title.toUpperCase(),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: Kv.muted)),
            ),
            KvCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (final (i, n) in items.indexed) ...[
                  if (i > 0) const Divider(indent: 68),
                  _NotificationRow(n: n, now: now, onTap: () => _open(context, ref, n)),
                ],
              ]),
            ),
          ]),
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unread > 0)
            TextButton(onPressed: () => _markAll(context, ref), child: const Text('Mark all read')),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(notificationInboxProvider),
        child: inbox.isLoading && list.isEmpty
            ? ListView(padding: const EdgeInsets.only(top: Kv.pad), children: const [ListSkeleton(rows: 6, height: 76)])
            : inbox.hasError && list.isEmpty
                ? ListView(children: [
                    EmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: "Couldn't load notifications",
                      message: 'Check your connection and try again.',
                      actionLabel: 'Try again',
                      onAction: () => ref.invalidate(notificationInboxProvider),
                    ),
                  ])
                : list.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 40),
                        EmptyState(
                          icon: Icons.notifications_none_rounded,
                          title: "You're all caught up",
                          message: 'Order, payment and savings updates will appear here.',
                        ),
                      ])
                    : ListView(padding: const EdgeInsets.all(Kv.pad), children: [
                        if (today.isNotEmpty) group('Today', today),
                        if (earlier.isNotEmpty) group('Earlier', earlier),
                      ]),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.n, required this.now, required this.onTap});
  final AppNotification n;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, bg, fg) = _styleFor(n.kind);
    return Material(
      color: n.read ? Colors.transparent : Kv.blueSoft.withValues(alpha: 0.45),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, size: 20, color: fg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Text(n.title,
                        style: TextStyle(fontSize: 15, fontWeight: n.read ? FontWeight.w500 : FontWeight.w700)),
                  ),
                  if (n.createdAt != null) ...[
                    const SizedBox(width: 8),
                    Text(relativeTime(n.createdAt!.toLocal(), now),
                        style: const TextStyle(fontSize: 12, color: Kv.subtle)),
                  ],
                ]),
                if (n.body.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(n.body, style: const TextStyle(fontSize: 13, color: Kv.muted, height: 1.4)),
                ],
              ]),
            ),
            SizedBox(
              width: 16,
              child: n.read
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(top: 6, left: 8),
                      child: Container(
                          width: 8, height: 8, decoration: const BoxDecoration(color: Kv.blue, shape: BoxShape.circle)),
                    ),
            ),
          ]),
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
