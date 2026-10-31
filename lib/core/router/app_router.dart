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

/// Pages that need a session, as the web's `RequireAuth` routes (payment,
/// profile, change password, wishlist, dashboard, passbook) plus the app's own
/// order and phone-verification screens. Everything else is open to guests.
bool _requiresAuth(String location) =>
    location == '/checkout' ||
    location == '/wishlist' ||
    location == '/dashboard' ||
    location == '/notifications' ||
    location == '/verify-phone' ||
    location.startsWith('/profile') ||
    location.startsWith('/orders') ||
    location.startsWith('/order-confirmation') ||
    location.startsWith('/savings-scheme/passbook');

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(authSessionProvider.notifier).restoreSession());
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    final error = session.restoreError;

    return Scaffold(
      body: Center(
        child: error == null
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off,
                        size: 48, color: Theme.of(context).colorScheme.outline),
                    const SizedBox(height: 16),
                    Text(error, textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => ref
                          .read(authSessionProvider.notifier)
                          .restoreSession(),
                      child: const Text('Try again'),
                    ),
                    TextButton(
                      // Escape hatch: abandon the unverifiable token and sign in
                      // fresh rather than being stranded on the splash screen.
                      onPressed: () =>
                          ref.read(authSessionProvider.notifier).clearSession(),
                      child: const Text('Sign in instead'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _GoRouterRefreshNotifier extends ChangeNotifier {
  _GoRouterRefreshNotifier(Ref ref) {
    ref.listen<AuthSessionState>(
        authSessionProvider, (_, __) => notifyListeners());
  }
}

final _routerRefreshProvider = Provider<_GoRouterRefreshNotifier>((ref) {
  final notifier = _GoRouterRefreshNotifier(ref);
  ref.onDispose(notifier.dispose);
  return notifier;
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(_routerRefreshProvider);

  return GoRouter(
    initialLocation: '/splash',
    errorBuilder: (context, state) => const NotFoundScreen(),
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(authSessionProvider);
      final location = state.matchedLocation;

      // "Restoring" also covers "restore failed, recoverably" — the splash
      // screen shows a retry, so holding the user here is intentional.
      if (session.isRestoring) {
        return location == '/splash' ? null : '/splash';
      }
      if (!session.isAuthenticated) {
        if (location == '/splash') return '/home';
        if (_requiresAuth(location)) {
          return Uri(
              path: '/login',
              queryParameters: {'from': state.uri.toString()}).toString();
        }
        return null;
      }
      if (location == '/splash' || _authRoutes.contains(location)) {
        // Just signed up: signup has already sent a WhatsApp code, so offer to enter it before Home.
        final user = session.user!;
        if (session.justSignedUp &&
            !user.phoneVerified &&
            (user.phone ?? '').isNotEmpty) {
          return '/verify-phone?sent=1';
        }
        // Back to the page that asked for sign-in.
        final from = state.uri.queryParameters['from'];
        return from != null &&
                from.startsWith('/') &&
                !from.startsWith('/login')
            ? from
            : '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
          path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/signup',
        builder: (context, state) => SignupScreen(
            initialPhone:
                state.extra as String? ?? state.uri.queryParameters['phone'],
            stallLink: state.uri.queryParameters['stall'] == '1'),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/verify-phone',
        builder: (context, state) => PhoneVerificationScreen(
            codeAlreadySent: state.uri.queryParameters['sent'] == '1'),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/shop',
        builder: (context, state) => ShopScreen(
            initialCategory: state.uri.queryParameters['category'],
            initialSearch: state.uri.queryParameters['search']),
      ),
      GoRoute(
        path: '/product/:id',
        builder: (context, state) =>
            ProductDetailScreen(productId: state.pathParameters['id']!),
      ),
      GoRoute(
          path: '/silver-rate',
          builder: (context, state) => const RatesScreen()),
      GoRoute(
          path: '/offers', builder: (context, state) => const OffersScreen()),
      GoRoute(
        path: '/savings-scheme',
        builder: (context, state) {
          // Old deep links (?passbook=...) land on the passbook's own page, as on the web.
          final legacy = state.uri.queryParameters['passbook'];
          return legacy != null && legacy.trim().isNotEmpty
              ? PassbookScreen(passbookNumber: legacy.trim())
              : const SavingsSchemeScreen();
        },
        routes: [
          GoRoute(
            path: 'passbook/:number',
            builder: (context, state) =>
                PassbookScreen(passbookNumber: state.pathParameters['number']!),
          ),
        ],
      ),
      GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardScreen()),
      GoRoute(
          path: '/wishlist',
          builder: (context, state) => const WishlistScreen()),
      GoRoute(
          path: '/gift-vouchers',
          builder: (context, state) => const GiftVouchersScreen()),
      GoRoute(
        path: '/order-confirmation/:id',
        builder: (context, state) =>
            OrderConfirmationScreen(orderId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),
      GoRoute(path: '/about', builder: (context, state) => const AboutScreen()),
      GoRoute(
          path: '/contact', builder: (context, state) => const ContactScreen()),
      GoRoute(path: '/faq', builder: (context, state) => const FaqScreen()),
      GoRoute(
          path: '/privacy-policy',
          builder: (context, state) => const PrivacyPolicyScreen()),
      GoRoute(path: '/terms', builder: (context, state) => const TermsScreen()),
      GoRoute(
          path: '/recently-viewed',
          builder: (context, state) => const RecentlyViewedScreen()),
      GoRoute(path: '/cart', builder: (context, state) => const CartScreen()),
      GoRoute(
          path: '/checkout',
          builder: (context, state) => const CheckoutScreen()),
      GoRoute(
          path: '/orders', builder: (context, state) => const OrdersScreen()),
      GoRoute(
        path: '/orders/:id',
        builder: (context, state) =>
            OrderDetailScreen(orderId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'invoice',
            builder: (context, state) =>
                InvoiceScreen(orderId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
        routes: [
          GoRoute(
            path: 'password',
            builder: (context, state) => const ChangePasswordScreen(),
          ),
          GoRoute(
            path: 'addresses',
            builder: (context, state) => const AddressBookScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const AddressFormScreen(),
              ),
              GoRoute(
                path: 'edit',
                // The address travels as `extra` rather than an id path param so
                // the form renders instantly without a second fetch.
                builder: (context, state) =>
                    AddressFormScreen(existing: state.extra as Address?),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
