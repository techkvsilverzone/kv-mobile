import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_session.dart';
import '../../core/ui/kv_ui.dart';
import '../notifications/notifications.dart';
import '../orders/data/order_repository.dart';
import '../savings/data/savings_repository.dart';
import '../wishlist/wishlist.dart';

/// Account tab: profile header, quick stats, and every account / help destination.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign back in any time with your mobile number.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (ok == true) await ref.read(authSessionProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final unread = ref.watch(unreadNotificationsProvider);
    void go(String path) => context.push(path);

    final help = MenuGroup(title: 'Help & information', children: [
      MenuRow(icon: Icons.support_agent_outlined, title: 'Contact us', onTap: () => go('/contact')),
      MenuRow(icon: Icons.help_outline_rounded, title: 'FAQ', onTap: () => go('/faq')),
      MenuRow(icon: Icons.storefront_outlined, title: 'About KV Silver Zone', onTap: () => go('/about')),
      MenuRow(icon: Icons.policy_outlined, title: 'Privacy policy', onTap: () => go('/privacy-policy')),
      MenuRow(icon: Icons.description_outlined, title: 'Terms & conditions', onTap: () => go('/terms')),
    ]);
    final explore = MenuGroup(title: 'Explore', children: [
      MenuRow(icon: Icons.show_chart_rounded, title: "Today's silver & gold rate", onTap: () => go('/silver-rate')),
      MenuRow(icon: Icons.local_offer_outlined, title: 'Offers', onTap: () => go('/offers')),
      MenuRow(icon: Icons.card_giftcard_outlined, title: 'Gift vouchers', onTap: () => go('/gift-vouchers')),
      MenuRow(icon: Icons.history_rounded, title: 'Recently viewed', onTap: () => go('/recently-viewed')),
    ]);

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Account')),
        body: ListView(padding: const EdgeInsets.all(Kv.pad), children: [
          KvCard(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Welcome to KV Silver Zone', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 24)),
              const SizedBox(height: 6),
              const Text('Sign in to track orders, save favourites and manage your savings schemes.',
                  style: TextStyle(color: Kv.muted)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: FilledButton(onPressed: () => go('/login?from=/profile'), child: const Text('Sign in'))),
                const SizedBox(width: 12),
                Expanded(child: OutlinedButton(onPressed: () => go('/signup'), child: const Text('Sign up'))),
              ]),
            ]),
          ),
          const SizedBox(height: Kv.gap),
          explore,
          const SizedBox(height: Kv.gap),
          help,
        ]),
      );
    }

    final orders = ref.watch(myOrdersProvider).valueOrNull?.length;
    final schemes = ref.watch(mySchemesProvider).valueOrNull?.length;
    final wishlist = ref.watch(wishlistIdsProvider).valueOrNull?.length;
    final initials = user.name.trim().isEmpty
        ? '?'
        : user.name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0].toUpperCase()).join();

    Widget stat(String label, int? n, String path) => Expanded(
          child: InkWell(
            borderRadius: Kv.smallRadius,
            onTap: () => go(path),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(children: [
                Text(n == null ? '–' : '$n', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(fontSize: 12, color: Kv.muted)),
              ]),
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Account'), actions: [
        IconButton(
          tooltip: 'Notifications',
          onPressed: () => go('/notifications'),
          icon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.notifications_none_rounded)),
        ),
      ]),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myOrdersProvider);
          ref.invalidate(mySchemesProvider);
          ref.invalidate(wishlistIdsProvider);
          ref.invalidate(notificationInboxProvider);
        },
        child: ListView(padding: const EdgeInsets.all(Kv.pad), children: [
          KvCard(
            onTap: () => go('/profile/edit'),
            child: Row(children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Kv.ink,
                child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(user.phone?.isNotEmpty == true ? user.phone! : user.email,
                      style: const TextStyle(color: Kv.muted, fontSize: 13)),
                ]),
              ),
              const Text('Edit', style: TextStyle(color: Kv.blue, fontWeight: FontWeight.w600)),
            ]),
          ),
          if ((user.phone ?? '').isNotEmpty && !user.phoneVerified) ...[
            const SizedBox(height: 12),
            KvCard(
              color: Kv.warningSoft,
              onTap: () => go('/verify-phone'),
              child: const Row(children: [
                Icon(Icons.verified_user_outlined, color: Kv.warning),
                SizedBox(width: 12),
                Expanded(child: Text('Verify your mobile number to secure your account',
                    style: TextStyle(color: Color(0xFF7C3A06), fontWeight: FontWeight.w500))),
                Icon(Icons.chevron_right, color: Kv.warning),
              ]),
            ),
          ],
          const SizedBox(height: 12),
          KvCard(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
              stat('Orders', orders, '/orders'),
              const SizedBox(height: 32, child: VerticalDivider(color: Kv.line)),
              stat('Schemes', schemes, '/savings-scheme'),
              const SizedBox(height: 32, child: VerticalDivider(color: Kv.line)),
              stat('Wishlist', wishlist, '/wishlist'),
            ]),
          ),
          const SizedBox(height: Kv.gap),
          MenuGroup(title: 'My account', children: [
            MenuRow(icon: Icons.receipt_long_outlined, title: 'My orders', onTap: () => go('/orders')),
            MenuRow(icon: Icons.assignment_return_outlined, title: 'Returns', onTap: () => go('/returns')),
            MenuRow(icon: Icons.favorite_border_rounded, title: 'Wishlist', onTap: () => go('/wishlist')),
            MenuRow(
              icon: Icons.notifications_none_rounded,
              title: 'Notifications',
              trailing: unread > 0
                  ? StatusPill('$unread new', tone: PillTone.info)
                  : const Icon(Icons.chevron_right, color: Kv.subtle),
              onTap: () => go('/notifications'),
            ),
          ]),
          const SizedBox(height: Kv.gap),
          MenuGroup(title: 'Settings', children: [
            MenuRow(icon: Icons.person_outline_rounded, title: 'Personal details', onTap: () => go('/profile/edit')),
            MenuRow(icon: Icons.location_on_outlined, title: 'Saved addresses', onTap: () => go('/profile/addresses')),
            MenuRow(icon: Icons.lock_outline_rounded, title: 'Change password', onTap: () => go('/profile/password')),
          ]),
          const SizedBox(height: Kv.gap),
          explore,
          const SizedBox(height: Kv.gap),
          help,
          const SizedBox(height: Kv.gap),
          MenuGroup(children: [
            MenuRow(icon: Icons.logout_rounded, title: 'Sign out', danger: true, onTap: () => _signOut(context, ref)),
          ]),
          const SizedBox(height: 24),
          const Center(child: Text('KV Silver Zone', style: TextStyle(color: Kv.subtle, fontSize: 12))),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}
