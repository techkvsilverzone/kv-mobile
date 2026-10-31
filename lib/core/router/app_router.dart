import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/data/models/address.dart';
import '../../features/auth/presentation/address_book_screen.dart';
import '../../features/auth/presentation/address_form_screen.dart';
import '../../features/auth/presentation/change_password_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/phone_verification_screen.dart';
import '../../features/auth/presentation/profile_screen.dart';
import '../../features/account/account_screen.dart';
import '../../features/returns/returns_screen.dart';
import '../../app/shell.dart';
import '../../app/splash_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/cart/presentation/cart_screen.dart';
import '../../features/catalog/presentation/product_detail_screen.dart';
import '../../features/catalog/presentation/shop_screen.dart';
import '../../features/checkout/presentation/checkout_screen.dart';
import '../../features/gift_vouchers/gift_vouchers_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/orders/presentation/order_detail_screen.dart';
import '../../features/orders/presentation/invoice/invoice_screen.dart';
import '../../features/orders/presentation/order_confirmation_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/contact/presentation/contact_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/info/presentation/about_screen.dart';
import '../../features/info/presentation/faq_screen.dart';
import '../../features/info/presentation/privacy_policy_screen.dart';
import '../../features/info/presentation/terms_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/offers/offers_screen.dart';
import '../../features/rates/presentation/rates_screen.dart';
import '../../features/recently_viewed/recently_viewed_screen.dart';
import '../../features/savings/presentation/passbook/passbook_screen.dart';
import '../../features/savings/presentation/savings_scheme_screen.dart';
import '../../features/wishlist/wishlist_screen.dart';
import '../auth/auth_session.dart';
import '../widgets/not_found_screen.dart';

/// Sign-in screens: a signed-in user is sent on from these.
const _authRoutes = {'/login', '/signup', '/forgot-password'};

/// Pages that need a session (the web's `RequireAuth` set plus the app's own order,
/// returns and phone-verification screens). The Account tab itself is open: guests
/// see a sign-in card there.
bool requiresAuth(String location) =>
    location == '/checkout' ||
    location == '/wishlist' ||
    location == '/dashboard' ||
    location == '/notifications' ||
    location == '/verify-phone' ||
    location == '/returns' ||
    location.startsWith('/profile/') ||
    location.startsWith('/orders') ||
    location.startsWith('/order-confirmation') ||
    location.startsWith('/savings-scheme/passbook');

final rootNavigatorKey = GlobalKey<NavigatorState>();

class _GoRouterRefreshNotifier extends ChangeNotifier {
  _GoRouterRefreshNotifier(Ref ref) {
    ref.listen<AuthSessionState>(authSessionProvider, (_, __) => notifyListeners());
    ref.listen<bool>(splashDoneProvider, (_, __) => notifyListeners());
  }
}

final _routerRefreshProvider = Provider<_GoRouterRefreshNotifier>((ref) {
  final notifier = _GoRouterRefreshNotifier(ref);
  ref.onDispose(notifier.dispose);
  return notifier;
});

GoRoute _page(String path, Widget Function(GoRouterState s) build, {List<RouteBase> routes = const []}) =>
    GoRoute(path: path, builder: (context, state) => build(state), routes: routes);

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(_routerRefreshProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    errorBuilder: (context, state) => const NotFoundScreen(),
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(authSessionProvider);
      final location = state.matchedLocation;

      // Hold the animated splash until both the animation and the session restore finish.
      // "Restoring" also covers "restore failed, recoverably" — the splash offers a retry.
      if (session.isRestoring || !ref.read(splashDoneProvider)) {
        return location == '/splash' ? null : '/splash';
      }
      if (!session.isAuthenticated) {
        if (location == '/splash') return '/home';
        if (requiresAuth(location)) {
          return Uri(path: '/login', queryParameters: {'from': state.uri.toString()}).toString();
        }
        return null;
      }
      if (location == '/splash' || _authRoutes.contains(location)) {
        final user = session.user!;
        if (session.justSignedUp && !user.phoneVerified && (user.phone ?? '').isNotEmpty) {
          return '/verify-phone?sent=1';
        }
        return safeReturnPath(state.uri.queryParameters['from']);
      }
      return null;
    },
    routes: [
      _page('/splash', (_) => const SplashScreen()),
      _page('/login', (s) => LoginScreen(from: s.uri.queryParameters['from'])),
      GoRoute(
        path: '/signup',
        builder: (context, state) => SignupScreen(
            initialPhone: state.extra as String? ?? state.uri.queryParameters['phone'],
            stallLink: state.uri.queryParameters['stall'] == '1'),
      ),
      _page('/forgot-password', (_) => const ForgotPasswordScreen()),
      _page('/verify-phone', (s) => PhoneVerificationScreen(codeAlreadySent: s.uri.queryParameters['sent'] == '1')),

      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [_page('/home', (_) => const HomeScreen())]),
          StatefulShellBranch(routes: [
            _page('/shop', (s) => ShopScreen(
                initialCategory: s.uri.queryParameters['category'],
                initialSearch: s.uri.queryParameters['search'])),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/savings-scheme',
              builder: (context, state) {
                // Old deep links (?passbook=...) land on the passbook page, as on the web.
                final legacy = state.uri.queryParameters['passbook'];
                return legacy != null && legacy.trim().isNotEmpty
                    ? PassbookScreen(passbookNumber: legacy.trim())
                    : const SavingsSchemeScreen();
              },
              routes: [
                GoRoute(
                  path: 'passbook/:number',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) => PassbookScreen(passbookNumber: state.pathParameters['number']!),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [_page('/cart', (_) => const CartScreen())]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const AccountScreen(),
              routes: [
                GoRoute(path: 'edit', parentNavigatorKey: rootNavigatorKey, builder: (c, s) => const ProfileScreen()),
                GoRoute(
                    path: 'password', parentNavigatorKey: rootNavigatorKey, builder: (c, s) => const ChangePasswordScreen()),
                GoRoute(
                  path: 'addresses',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (c, s) => const AddressBookScreen(),
                  routes: [
                    GoRoute(path: 'new', parentNavigatorKey: rootNavigatorKey, builder: (c, s) => const AddressFormScreen()),
                    GoRoute(
                      path: 'edit',
                      parentNavigatorKey: rootNavigatorKey,
                      // The address travels as `extra` so the form renders without a second fetch.
                      builder: (c, s) => AddressFormScreen(existing: s.extra as Address?),
                    ),
                  ],
                ),
              ],
            ),
          ]),
        ],
      ),

      // Full-screen pages above the tab bar.
      _page('/product/:id', (s) => ProductDetailScreen(productId: s.pathParameters['id']!)),
      _page('/checkout', (_) => const CheckoutScreen()),
      _page('/orders', (_) => const OrdersScreen()),
      GoRoute(
        path: '/orders/:id',
        builder: (context, state) => OrderDetailScreen(orderId: state.pathParameters['id']!),
        routes: [
          GoRoute(path: 'invoice', builder: (c, s) => InvoiceScreen(orderId: s.pathParameters['id']!)),
        ],
      ),
      _page('/order-confirmation/:id', (s) => OrderConfirmationScreen(orderId: s.pathParameters['id']!)),
      _page('/returns', (_) => const ReturnsScreen()),
      _page('/notifications', (_) => const NotificationsScreen()),
      _page('/wishlist', (_) => const WishlistScreen()),
      _page('/dashboard', (_) => const DashboardScreen()),
      _page('/silver-rate', (_) => const RatesScreen()),
      _page('/offers', (_) => const OffersScreen()),
      _page('/recently-viewed', (_) => const RecentlyViewedScreen()),
      _page('/gift-vouchers', (_) => const GiftVouchersScreen()),
      _page('/about', (_) => const AboutScreen()),
      _page('/contact', (_) => const ContactScreen()),
      _page('/faq', (_) => const FaqScreen()),
      _page('/privacy-policy', (_) => const PrivacyPolicyScreen()),
      _page('/terms', (_) => const TermsScreen()),
    ],
  );
});

/// Where to go after signing in: the page that asked for it, else Home.
String safeReturnPath(String? from) =>
    from != null && from.startsWith('/') && !from.startsWith('/login') && !from.startsWith('/signup')
        ? from
        : '/home';
