import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_session.dart';

/// The web's navbar links, account menu and footer links in one menu.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  static const _nav = [
    ('Home', '/home', Icons.home_outlined),
    ('Collections', '/shop', Icons.diamond_outlined),
    ('Silver Rate', '/silver-rate', Icons.trending_up),
    ('Savings Scheme', '/savings-scheme', Icons.savings_outlined),
    ('Gift Vouchers', '/gift-vouchers', Icons.card_giftcard),
    ('About', '/about', Icons.info_outline),
    ('Contact', '/contact', Icons.mail_outline),
  ];
  static const _account = [
    ('My Profile', '/profile', Icons.person_outline),
    ('My Orders', '/orders', Icons.receipt_long_outlined),
    ('My Dashboard', '/dashboard', Icons.dashboard_outlined),
    ('My Wishlist', '/wishlist', Icons.favorite_border),
    ('Notifications', '/notifications', Icons.notifications_none),
  ];
  static const _more = [
    ('Deals & Offers', '/offers', Icons.sell_outlined),
    ('Recently Viewed', '/recently-viewed', Icons.schedule),
    ('FAQ', '/faq', Icons.help_outline),
    ('Privacy Policy', '/privacy-policy', Icons.privacy_tip_outlined),
    ('Terms & Conditions', '/terms', Icons.description_outlined),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authed = ref.watch(authSessionProvider).isAuthenticated;

    Widget item((String, String, IconData) e) => ListTile(
          leading: Icon(e.$3, size: 20),
          title: Text(e.$1),
          dense: true,
          onTap: () {
            Navigator.pop(context);
            e.$2 == '/home' ? context.go('/home') : context.push(e.$2);
          },
        );
    Widget header(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(t.toUpperCase(),
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant, letterSpacing: 1.6)),
        );

    return Drawer(
      child: SafeArea(
        child: ListView(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('KV Silver Zone', style: theme.textTheme.headlineSmall),
          ),
          ..._nav.map(item),
          const Divider(),
          header('My Account'),
          if (authed)
            ..._account.map(item)
          else
            item(('Sign in', '/login', Icons.login)),
          const Divider(),
          header('More'),
          ..._more.map(item),
        ]),
      ),
    );
  }
}
