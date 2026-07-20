import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/data/models/address.dart';
import '../../features/auth/presentation/address_book_screen.dart';
import '../../features/auth/presentation/address_form_screen.dart';
import '../../features/auth/presentation/change_password_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/profile_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/catalog/presentation/product_detail_screen.dart';
import '../../features/catalog/presentation/shop_screen.dart';
import '../auth/auth_session.dart';
import 'home_stub_screen.dart';

/// Reachable while signed out. Everything else redirects to `/login`.
const _publicRoutes = {'/login', '/signup', '/forgot-password'};

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(authSessionProvider.notifier).restoreSession());
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
                    Icon(Icons.cloud_off, size: 48, color: Theme.of(context).colorScheme.outline),
                    const SizedBox(height: 16),
                    Text(error, textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => ref.read(authSessionProvider.notifier).restoreSession(),
                      child: const Text('Try again'),
                    ),
                    TextButton(
                      // Escape hatch: abandon the unverifiable token and sign in
                      // fresh rather than being stranded on the splash screen.
                      onPressed: () => ref.read(authSessionProvider.notifier).clearSession(),
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
    ref.listen<AuthSessionState>(authSessionProvider, (_, __) => notifyListeners());
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
        return _publicRoutes.contains(location) ? null : '/login';
      }
      if (location == '/splash' || _publicRoutes.contains(location)) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomeStubScreen()),
      GoRoute(path: '/shop', builder: (context, state) => const ShopScreen()),
      GoRoute(
        path: '/product/:id',
        builder: (context, state) =>
            ProductDetailScreen(productId: state.pathParameters['id']!),
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
