import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_session.dart';

/// Placeholder landing screen. The real Home (category tiles + featured
/// products) arrives with the Shop feature; this exists so the authenticated
/// half of the app has somewhere to land and a route into the profile.
class HomeStubScreen extends ConsumerWidget {
  const HomeStubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('KV Silver Zone'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'My profile',
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                user == null ? 'Welcome' : 'Welcome, ${user.name}',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Shopping is not built yet — browse, cart and checkout arrive '
                'with the Shop feature.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.tonalIcon(
                onPressed: () => context.push('/profile'),
                icon: const Icon(Icons.person_outline),
                label: const Text('My profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
